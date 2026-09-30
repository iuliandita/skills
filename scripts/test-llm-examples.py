#!/usr/bin/env python3
"""Exercise selected Markdown examples without provider SDKs or network access."""

import contextlib
import io
import re
import sys
import types
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
REFERENCES = ROOT / "skills/llm-app-development/references"


def example(filename: str, heading: str, index: int = 0) -> str:
    text = (REFERENCES / filename).read_text()
    section = text.split(heading, 1)[1]
    section = re.split(r"\n###? ", section, maxsplit=1)[0]
    return re.findall(r"```python\n(.*?)\n```", section, re.S)[index]


def fake_client(response: types.SimpleNamespace):
    calls = []

    def create(**kwargs):
        calls.append(kwargs)
        return response

    endpoint = types.SimpleNamespace(create=create)
    return types.SimpleNamespace(messages=endpoint, responses=endpoint), calls


def block(kind: str, **kwargs) -> types.SimpleNamespace:
    return types.SimpleNamespace(type=kind, **kwargs)


def run(source: str, response: types.SimpleNamespace):
    client, calls = fake_client(response)
    namespace = {"client": client, "text": "Example person"}
    validations = []
    module = types.ModuleType("jsonschema")

    def validate(instance, schema, format_checker):
        validations.append((instance, schema, format_checker))
        assert schema["properties"]["age"]["minimum"] == 0
        assert schema["properties"]["age"]["maximum"] == 150
        assert schema["properties"]["topics"]["maxItems"] == 10
        if instance.get("age", 0) > 150 or len(instance.get("topics", [])) > 10:
            raise ValueError("application constraint violated")

    module.validate = validate
    module.FormatChecker = object
    with patch.dict(sys.modules, {"jsonschema": module}):
        exec(compile(source, "<Markdown example>", "exec"), namespace)
    namespace["_validations"] = validations
    return namespace, calls


def rejects(source: str, response: types.SimpleNamespace) -> None:
    try:
        run(source, response)
    except (RuntimeError, ValueError):
        return
    raise AssertionError("Example accepted an invalid provider response")


def check_schema(schema: dict) -> None:
    unsupported = {"minimum", "maximum", "maxItems", "minItems"}
    assert not unsupported.intersection(schema), schema
    if "format" in schema:
        assert schema["format"] == "email", schema
    if schema.get("type") == "object":
        assert schema.get("additionalProperties") is False, schema
        for child in schema.get("properties", {}).values():
            check_schema(child)
    if "items" in schema:
        check_schema(schema["items"])


def check_classifier() -> None:
    source = example("safety.md", "### Application-level content policy")
    cases = [
        ("end_turn", [block("thinking"), block("text", text=" SAFE ")], "safe"),
        ("end_turn", [block("text", text="blocked")], "blocked"),
        ("refusal", [block("text", text="safe")], "needs_review"),
        ("max_tokens", [block("text", text="safe")], "needs_review"),
        ("end_turn", [block("thinking")], "needs_review"),
        ("end_turn", [block("text", text="unexpected")], "needs_review"),
    ]
    for stop, content, expected in cases:
        namespace, calls = run(source, types.SimpleNamespace(stop_reason=stop, content=content))
        result = namespace["classify_content"]("test text")
        assert result.value == expected, (stop, expected, result)
        request = calls[0]
        assert request["model"] == "claude-sonnet-5-5"
        assert request["thinking"] == {"type": "between_tools"}
        assert request["output_config"]["effort"] == "low"


def check_anthropic_structured() -> None:
    heading = "### Anthropic - structured output"
    source = example("llm-patterns.md", heading)
    value = '{"name":"Ada","age":37,"email":"ada@example.com","topics":[]}'
    response = types.SimpleNamespace(stop_reason="end_turn", content=[block("thinking"), block("text", text=value)])
    namespace, calls = run(source, response)
    assert namespace["data"]["name"] == "Ada"
    assert len(namespace["_validations"]) == 1
    request = calls[0]
    assert request["model"] == "claude-sonnet-5-5"
    check_schema(request["output_config"]["format"]["schema"])
    for stop in ("refusal", "max_tokens"):
        rejects(source, types.SimpleNamespace(stop_reason=stop, content=response.content))
    for content in ([block("thinking")], [block("text", text="invalid JSON")]):
        rejects(source, types.SimpleNamespace(stop_reason="end_turn", content=content))
    rejects(source, types.SimpleNamespace(stop_reason="end_turn", content=[block("text", text='{"name":"Ada","email":"ada@example.com","age":151}')]))

    # The strict-tool fence explicitly reuses the first fence's schema setup.
    strict = source.split("\nresponse = ", 1)[0] + "\n" + example("llm-patterns.md", heading, 1)
    tool = block("tool_use", name="extract_info", input={"name": "Ada", "email": "ada@example.com"})
    namespace, calls = run(strict, types.SimpleNamespace(stop_reason="tool_use", content=[block("thinking"), tool]))
    assert namespace["data"] == tool.input
    assert len(namespace["_validations"]) == 1
    request = calls[0]
    assert request["model"] == "claude-sonnet-5-5"
    assert request["tool_choice"] == {"type": "auto"}
    assert request["tools"][0]["strict"] is True
    check_schema(request["tools"][0]["input_schema"])
    wrong_tool = block("tool_use", name="other_tool", input=tool.input)
    for stop, content in [("end_turn", [block("text", text="No tool")]), ("refusal", []), ("max_tokens", [tool]), ("tool_use", [wrong_tool]), ("tool_use", [tool, tool])]:
        rejects(strict, types.SimpleNamespace(stop_reason=stop, content=content))


def check_openai_responses() -> None:
    source = example("llm-patterns.md", "### OpenAI Responses (Python)")
    for status, output in [("completed", "Retry limits prevent endless retries."), ("incomplete", "partial"), ("completed", "")]:
        response = types.SimpleNamespace(status=status, output_text=output)
        client, calls = fake_client(response)
        module = types.ModuleType("openai")
        module.OpenAI = lambda: client
        with patch.dict(sys.modules, {"openai": module}), contextlib.redirect_stdout(io.StringIO()) as captured:
            if status != "completed" or not output:
                rejects(source, response)
            else:
                run(source, response)
                assert output in captured.getvalue()
        request = calls[0]
        assert request["model"] == "gpt-6.1-sol"
        assert request["reasoning"]["effort"] in {"low", "medium", "high", "xhigh", "max"}
        assert not {"temperature", "top_p", "messages", "max_tokens"}.intersection(request)


if __name__ == "__main__":
    check_classifier()
    check_anthropic_structured()
    check_openai_responses()
    print("All selected LLM example behavior tests passed.")
