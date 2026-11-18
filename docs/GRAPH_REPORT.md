# Graph Report - pontimaps_app  (2026-11-17)

## Corpus Check
- Corpus is ~9,342 words - fits in a single context window. You may not need a graph.

## Summary
- 18 nodes · 18 edges · 4 communities (1 shown, 3 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3

## God Nodes (most connected - your core abstractions)
1. `MyHomePage` - 3 edges
2. `_MyHomePageState` - 3 edges
3. `MyApp` - 2 edges
4. `title` - 1 edges
5. `_counter` - 1 edges
6. `main` - 1 edges
7. `build` - 1 edges
8. `createState` - 1 edges
9. `_incrementCounter` - 1 edges
10. `main` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (4 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.29
Nodes (6): build, _counter, createState, _incrementCounter, main, title

## Knowledge Gaps
- **7 isolated node(s):** `title`, `_counter`, `main`, `build`, `createState` (+2 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 12 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MyApp` connect `Community 3` to `Community 0`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._
- **What connects `title`, `_counter`, `main` to the rest of the system?**
  _7 weakly-connected nodes found - possible missing edges._
- **Why does `MyHomePage` connect `Community 2` to `Community 0`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._
- **Why does `_MyHomePageState` connect `Community 2` to `Community 0`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._