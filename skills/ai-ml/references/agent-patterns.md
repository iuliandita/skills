# Agent Patterns

Detailed patterns for building agent systems -- tool orchestration, state management,
multi-agent architectures, human-in-the-loop, and production deployment.

---

## Table of Contents

1. Agent Loop Fundamentals
2. Custom Agent Loop
3. LangGraph Agents
4. OpenAI Agents SDK
5. Multi-Agent Architectures
6. Memory and State Management
7. Human-in-the-Loop
8. Production Deployment
9. Anti-Patterns

---

## 1. Agent Loop Fundamentals

Every agent follows the same core loop:

1. **Observe** -- gather context (user input, tool results, memory)
2. **Think** -- model decides next action (tool call or final response)
3. **Act** -- execute the chosen tool
4. **Update** -- add the result to state
5. **Check** -- is the task done? If not, loop back to step 1.

The differences between frameworks are in how they manage state persistence,
handle branching/cycles, and coordinate multiple agents.

---

## 2. Custom Agent Loop

For simple agents, a raw loop with the provider SDK is the lightest option.
Note: this example uses the sync client for clarity. In production (especially
request handlers), use `AsyncAnthropic` and `await` to avoid blocking.

```python
import anthropic

client = anthropic.Anthropic()  # use AsyncAnthropic() + async/await in production

def run_agent(user_query: str, tools: list[dict], max_iterations: int = 15) -> str:
    messages = [{"role": "user", "content": user_query}]
    iterations = 0

    while iterations < max_iterations:
        iterations += 1
        response = client.messages.create(
            model="claude-sonnet-4-6-20250514",
            max_tokens=4096,
            tools=tools,
            messages=messages,
        )

        messages.append({"role": "assistant", "content": response.content})

        if response.stop_reason == "end_turn":
            # Extract final text response
            text_blocks = [b.text for b in response.content if b.type == "text"]
            return "\n".join(text_blocks)

        if response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    try:
                        result = execute_tool(block.name, block.input)
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": str(result),
                        })
                    except Exception as e:
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": f"Error: {e}",
                            "is_error": True,
                        })
            messages.append({"role": "user", "content": tool_results})

    return "Agent reached maximum iterations without completing the task."
```

### When to use a custom loop

- Fewer than 5 tools
- No need for persistence or checkpointing
- Linear execution (no branching or cycles)
- Want to avoid framework dependencies

---

## 3. LangGraph Agents

LangGraph models agents as state machines with nodes (functions) and edges (transitions).
Use it when you need cycles, conditional branching, or persistent state.

```python
from langgraph.graph import StateGraph, MessagesState, START, END
from langgraph.prebuilt import ToolNode

# Define tools
tools = [search_docs, create_ticket, send_email]
tool_node = ToolNode(tools)

# Define the decision function
def should_continue(state: MessagesState) -> str:
    last_message = state["messages"][-1]
    if last_message.tool_calls:
        return "tools"
    return END

# Build the graph
graph = StateGraph(MessagesState)
graph.add_node("agent", call_model)
graph.add_node("tools", tool_node)
graph.add_edge(START, "agent")
graph.add_conditional_edges("agent", should_continue, {"tools": "tools", END: END})
graph.add_edge("tools", "agent")

app = graph.compile()

# Run
result = app.invoke({"messages": [("user", "Find the latest docs on authentication")]})
```

### LangGraph checkpointing

Persist state across requests for long-running agents:

```python
from langgraph.checkpoint.sqlite import SqliteSaver

# Checkpointer persists state to SQLite (or Postgres, Redis, etc.)
checkpointer = SqliteSaver.from_conn_string("agent_state.db")
app = graph.compile(checkpointer=checkpointer)

# Each thread_id gets its own persistent state
config = {"configurable": {"thread_id": "user-123"}}
result = app.invoke({"messages": [("user", "Continue from where we left off")]}, config)
```

### When to use LangGraph

- Agent needs cycles (revisiting nodes based on results)
- Complex conditional logic (different paths based on tool results)
- Need persistent state across requests (conversations, long-running tasks)
- Multi-step workflows with human approval gates

---

## 4. OpenAI Agents SDK

Lightweight multi-agent framework with built-in tracing and handoffs:

```python
from agents import Agent, Runner, function_tool

@function_tool
def search_knowledge_base(query: str) -> str:
    """Search the internal knowledge base."""
    return perform_search(query)

support_agent = Agent(
    name="Support Agent",
    instructions="Help users with technical issues. Use the knowledge base.",
    tools=[search_knowledge_base],
    model="gpt-4o",
)

# Run the agent
result = Runner.run_sync(support_agent, "How do I reset my API key?")
print(result.final_output)
```

### Agent handoffs

Route between specialized agents:

```python
billing_agent = Agent(
    name="Billing Agent",
    instructions="Handle billing and subscription questions.",
    tools=[get_invoice, update_subscription],
)

triage_agent = Agent(
    name="Triage Agent",
    instructions="Route to the appropriate specialist agent.",
    handoffs=[support_agent, billing_agent],
)

# Triage agent decides which specialist handles the request
result = Runner.run_sync(triage_agent, user_message)
```

### When to use OpenAI Agents SDK

- OpenAI models as the primary provider
- Need multi-agent handoffs with minimal code
- Want built-in tracing for debugging
- Simple agent workflows without complex state machines

---

## 5. Multi-Agent Architectures

### Supervisor pattern

One "manager" agent delegates to specialized worker agents:

```
User -> Supervisor -> [Research Agent, Code Agent, Review Agent] -> Supervisor -> User
```

- Supervisor decides which worker to invoke based on the task
- Workers have specialized tools and instructions
- Supervisor synthesizes results from multiple workers

### Pipeline pattern

Agents process in sequence, each adding to the context:

```
User -> Planner -> Researcher -> Writer -> Editor -> User
```

- Each agent has a focused role
- Output of one agent becomes input to the next
- Easy to debug (linear flow)

### Debate / critique pattern

Multiple agents review the same problem from different angles:

```
User -> [Agent A, Agent B, Agent C] -> Synthesizer -> User
```

- Useful for high-stakes decisions
- Agents can challenge each other's reasoning
- Synthesizer agent merges perspectives

### Choosing an architecture

| Architecture | Best for | Complexity |
|-------------|----------|------------|
| Single agent | Most tasks | Low |
| Supervisor + workers | Tasks requiring diverse tools | Medium |
| Pipeline | Sequential processing (draft -> review -> publish) | Medium |
| Debate / critique | High-stakes decisions, quality-critical output | High |

**Start with a single agent.** Split into multi-agent only when a single agent can't handle
the tool count (>15) or needs genuinely different reasoning strategies for subtasks.

---

## 6. Memory and State Management

### Short-term memory (conversation context)

The message history itself. Manage by:
- Trimming old messages when context gets large
- Summarizing conversation history periodically
- Keeping a sliding window of recent messages

### Working memory (scratchpad)

Let the agent maintain structured notes during a task:

```python
# Add a "memory" tool that writes to a scratchpad
@function_tool
def save_note(key: str, value: str) -> str:
    """Save a note for later reference during this task."""
    scratchpad[key] = value
    return f"Saved: {key}"

@function_tool
def get_notes() -> str:
    """Retrieve all saved notes."""
    return json.dumps(scratchpad, indent=2)
```

### Long-term memory (cross-session)

Persist facts, preferences, and learned context across sessions:

```python
# Store in a vector DB or key-value store
def remember(user_id: str, fact: str, embedding: list[float]):
    memory_store.upsert(
        id=f"{user_id}:{hash(fact)}",
        vector=embedding,
        payload={"user_id": user_id, "fact": fact, "timestamp": now()},
    )

def recall(user_id: str, query_embedding: list[float], limit: int = 5) -> list[str]:
    results = memory_store.query(
        vector=query_embedding,
        filter={"user_id": user_id},
        limit=limit,
    )
    return [r.payload["fact"] for r in results]
```

---

## 7. Human-in-the-Loop

### Approval gates

Pause agent execution for human approval before high-impact actions:

```python
# LangGraph interrupt pattern
from langgraph.types import interrupt

def execute_action(state):
    action = state["pending_action"]

    # Ask for human approval
    approval = interrupt({
        "action": action["name"],
        "params": action["params"],
        "question": f"Approve {action['name']} with params {action['params']}?",
    })

    if approval == "approved":
        return execute_tool(action["name"], action["params"])
    else:
        return {"messages": ["Action was rejected by user."]}
```

### When to require approval

- Destructive operations (delete, overwrite, deploy)
- External communications (sending emails, creating tickets)
- Financial operations (payments, refunds)
- Any action that can't be easily undone

---

## 8. Production Deployment

### Timeouts and limits

```python
AGENT_CONFIG = {
    "max_iterations": 20,           # prevent infinite loops
    "max_tokens_per_turn": 4096,    # limit per-call cost
    "total_token_budget": 100_000,  # cap total conversation cost
    "timeout_seconds": 300,         # 5 min max for the full agent run
    "tool_timeout_seconds": 30,     # per-tool execution timeout
}
```

### Observability

Log every step of agent execution:

```python
import structlog

log = structlog.get_logger()

def agent_step(iteration: int, action: str, tool_name: str | None, tokens: int):
    log.info(
        "agent_step",
        iteration=iteration,
        action=action,
        tool_name=tool_name,
        tokens_used=tokens,
        cumulative_cost=calculate_cost(tokens),
    )
```

### Error recovery

- **Tool failure**: return error to the model, let it retry or try a different approach
- **Rate limit**: pause and retry with backoff (don't count as an iteration)
- **Model error**: retry once, then fail gracefully with partial results
- **Timeout**: save state, return what's available, allow resume

---

## 9. Anti-Patterns

| Anti-pattern | Why it's bad | Fix |
|-------------|-------------|-----|
| No iteration limit | Agent loops forever, burns budget | Set max_iterations (10-20) |
| Catching all exceptions silently | Agent can't learn from errors | Return errors to the model |
| Tools with side effects and no confirmation | Accidental emails, deletions | Add approval gates |
| Giant system prompts with all instructions | Wastes tokens every turn | Use tools to fetch relevant instructions |
| Sharing state via global variables | Race conditions, debugging nightmare | Pass state explicitly through the graph |
| Starting with multi-agent | Premature complexity | Start single-agent, split when needed |
| No cost tracking | Surprise bills | Track tokens per request, set budgets |
