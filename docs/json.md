# JSON Output Format

The `bgv2json` command outputs files in [JSON Lines](https://jsonlines.org/) format - one JSON object for each graph, one per line.

Each graph is of the format:

```js
{
  "name": ...,
  "props": {...},
  "nodes": [...],
  "edges": [...]
}
```

Each node is of the format:

```js
{
  "id": ...,
  "props": {...}
}
```

Each edge is of the format:

```js
{
  "from": ..., // node id
  "to": ..., // node id
  "props": {...}
}
```

Note that `bgv2json` runs annotations, so for example all nodes have a `"label"` property with an easy-to-use name.
