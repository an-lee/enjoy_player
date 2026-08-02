# Examples

### Fixing Unbounded Height (ListView in Column)

**Input (Error State):**
```dart
// Throws "Vertical viewport was given unbounded height"
Column(
  children: <Widget>[
    const Text('Header'),
    ListView(
      children: const <Widget>[
        ListTile(title: Text('Item 1')),
        ListTile(title: Text('Item 2')),
      ],
    ),
  ],
)
```

**Output (Resolved State):**
```dart
// Wrap ListView in Expanded to constrain its height to the remaining Column space
Column(
  children: <Widget>[
    const Text('Header'),
    Expanded(
      child: ListView(
        children: const <Widget>[
          ListTile(title: Text('Item 1')),
          ListTile(title: Text('Item 2')),
        ],
      ),
    ),
  ],
)
```

### Fixing Unbounded Width (TextField in Row)

**Input (Error State):**
```dart
// Throws "An InputDecorator...cannot have an unbounded width"
Row(
  children: [
    const Icon(Icons.search),
    TextField(),
  ],
)
```

**Output (Resolved State):**
```dart
// Wrap TextField in Expanded to constrain its width to the remaining Row space
Row(
  children: [
    const Icon(Icons.search),
    Expanded(
      child: TextField(),
    ),
  ],
)
```

### Fixing RenderFlex Overflow

**Input (Error State):**
```dart
// Throws "A RenderFlex overflowed by X pixels on the right"
Row(
  children: [
    const Icon(Icons.info),
    const Text('This is a very long text string that will definitely overflow the available screen width and cause a RenderFlex error.'),
  ],
)
```

**Output (Resolved State):**
```dart
// Wrap the Text widget in Expanded to force it to wrap within the available constraints
Row(
  children: [
    const Icon(Icons.info),
    Expanded(
      child: const Text('This is a very long text string that will definitely overflow the available screen width and cause a RenderFlex error.'),
    ),
  ],
)
```
