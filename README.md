# xdm-persistence

A persistence solution for the XPath 3.1 Data Model (XDM): serialize any XDM
value — nodes, maps, arrays, and atomic values, in any combination or nesting
— to XML, and parse that XML back into an equivalent value.

Two modes are available. The default mode's requirement is that the
following expression MUST return true for every supported XDM value:

```xquery
deep-equal(
  $x, 
  xdm:parse(xdm:serialize($x))
)
```

An opt-in [reference-preserving mode](#reference-preserving-mode) goes
further for node-valued data: it preserves node *identity* (the same node
referenced twice comes back as the same node) and full axis navigation
(`ancestor::`, `following-sibling::`, ...) across independently-referenced
nodes from the same source document, `deep-equal` still holds.
## Background

The starting idea — mirroring an XDM value's shape into an XML tree — comes
from [xpath-result-serializer](https://github.com/pgfearo/xpath-result-serializer),
which used that tree to pretty-print XPath results for debugging (truncated
text, XPath locations, ANSI colors) but was never meant to be parsed back.
The redesign for genuine round-tripping — the typed atomic-value encoding,
the namespaced wrapper vocabulary, and the parser — was implemented with
[Claude](https://claude.com/claude-code).

## How it works

Every value is mirrored into an XML tree in the `xdm:` namespace
(`http://deltaxignia.com/ns/xdm-persistence`):

- **Element and document nodes** are self-describing XML already, so they
  need no extra encoding: elements are copied in as-is, and a document
  node's children are copied under `xdm:document` (a document node can't
  itself be a child of an element).
- **Text, comment, processing-instruction, attribute and namespace nodes**
  get a small dedicated wrapper element each, since none of them can appear
  as a bare top-level item in XML on their own.
- **Maps** become `xdm:map`/`xdm:entry` — any atomic type is supported as a
  key (not just strings), and an entry's value is a full XDM sequence (0, 1,
  or many items), not just a single item.
- **Arrays** become `xdm:array`/`xdm:member`, the same way.
- **Atomic values** become `xdm:atomic`, tagged with the precise built-in
  XSD type (`xs:integer`, `xs:date`, `xs:QName`, ...) so the value casts
  back to exactly the same type, not just "string/number/boolean". The XML
  Schema namespace is declared on the root element (as `xs:`), so `type`
  and `key-type` are genuine, resolvable QNames — a document that binds
  that namespace to a different prefix parses just as well.

For example, `map { 'name': 'Ada Lovelace', 'scores': (7, 9, 10), 'bio': <p>Mathematician.</p> }`
serializes to:

```xml
<xdm:sequence xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
              xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xdm:item>
    <xdm:map>
      <xdm:entry key="scores" key-type="xs:string">
        <xdm:item><xdm:atomic type="xs:integer">7</xdm:atomic></xdm:item>
        <xdm:item><xdm:atomic type="xs:integer">9</xdm:atomic></xdm:item>
        <xdm:item><xdm:atomic type="xs:integer">10</xdm:atomic></xdm:item>
      </xdm:entry>
      <xdm:entry key="bio" key-type="xs:string">
        <xdm:item><p>Mathematician.</p></xdm:item>
      </xdm:entry>
      <xdm:entry key="name" key-type="xs:string">
        <xdm:item><xdm:atomic type="xs:string">Ada Lovelace</xdm:atomic></xdm:item>
      </xdm:entry>
    </xdm:map>
  </xdm:item>
</xdm:sequence>
```

Note `scores` holding three `xdm:item`s under one `xdm:entry` (a map value is an
arbitrary sequence, not just a single item), and `bio` holding the `<p>` element
completely unwrapped, exactly as it was written.

## Reference-preserving mode

The functions `xdm:serialize-with-refs`/`xdm:parse-with-refs` are for a second, opt-in
serialization mode with a stronger contract than `deep-equal`: for any node
whose `root()` is a real `document-node()` (read via `doc()`, or otherwise
part of a genuine source document rather than a one-off constructed
fragment), it preserves that node's *identity* and its full position within
the original document — not just its own shape.

```xml
<xsl:variable name="person" select="doc('person.xml')/person"/>

<xsl:variable name="value" as="item()*" select="
  map { 'author': $person, 'reviewer': $person, 'author-bio': $person/bio }"/>

<xsl:variable name="serialized" select="xdm:serialize-with-refs($value)"/>
<xsl:variable name="restored" as="map(*)" select="xdm:parse-with-refs($serialized)[1]"/>

<!-- $restored?author is $restored?reviewer                  - true, same node back -->
<!-- $restored?author-bio/parent::person is $restored?author - true, real axis navigation -->
```

Both `author` and `reviewer` resolve against one shared reconstruction of
`person.xml` rather than being copied independently, so `is` and every XPath
axis (`ancestor::`, `following-sibling::`, ...) work exactly as they would
on the original document — not just on values that happen to look the same.

A node whose `root()` is *not* a document-node() (a one-off constructed
fragment with no real document to reconstruct) is embedded inline exactly as
`xdm:serialize` does; only genuinely document-rooted nodes are referenced.
Maps, arrays and atomic values persist identically to the default mode.

This is a distinct XML format (`xdm:context` at the root, not
`xdm:sequence`) that the default mode's parser can't read, and vice versa.
If you're handed a persisted document without knowing in advance which mode
wrote it, use `xdm:parse-any($doc)` (or check first with
`xdm:is-refs-format($doc)`) rather than guessing.

`base-uri()` of a resolved node is also restored to the original source
document's location (via `xml:base`) when there was a real one to restore —
not left pointing at wherever the value was parsed back, which is what it
would default to otherwise.

**Known limitation:** a `document-node()` referenced directly (as opposed to
a node within one) is reconstructed fresh on every resolution, so identity
is not preserved between two direct references to the very same
`document-node()`. Identity for every node *within* a document is
unaffected by this.

| File | Purpose |
|---|---|
| `src/xdm-serializer-refs.xsl` | `xdm:serialize-with-refs($value)` |
| `src/xdm-parser-refs.xsl` | `xdm:parse-with-refs($doc)` |

## Abbreviated XDM Syntax Views

The above example is quite verbose, this same XDM can be rendered more simply (but less precisely) as:

```js
{
  'scores': (7, 9, 10),
  'bio':
  <p>Mathematician.</p>,
  'name': 'Ada Lovelace'
}
```

The companion __[xdm-viewer](https://github.com/pgfearo/xdm-viewer)__ project provides alternate html and text views with this json-like syntax on top of the serialized xdm. The reference-preserving mode includes node values as well, but also identifies the document (position in the document pool) and path for each node. __The abbreviated syntax improves readability but by design does not support round-tripping.__

## Files

| File | Purpose |
|---|---|
| `src/xdm-types.xsl` | Shared vocabulary: the `xdm:` namespace, atomic type-name detection, and lexical cast-back |
| `src/xdm-serializer-common.xsl` | Internal: node-kind classification and atomic/node encoding shared by both serializer modes |
| `src/xdm-parser-common.xsl` | Internal: standalone attribute/namespace reconstruction shared by both parser modes |
| `src/xdm-serializer.xsl` | `xdm:serialize($value)`, `xdm:serialize-to-string($value)` |
| `src/xdm-parser.xsl` | `xdm:parse($doc)`, `xdm:parse-string($xml)` |
| `src/xdm-persistence.xsl` | The one file to import — assembles every module above (and the [reference-preserving mode](#reference-preserving-mode)'s two files), plus `xdm:parse-any`/`xdm:is-refs-format` for reading a document without knowing in advance which mode wrote it |

Import `xdm-persistence.xsl` in your own stylesheets rather than any of the
individual files above (or the reference-preserving mode's) — none of
them import their own dependencies; `xdm-persistence.xsl` is the one place
that assembles the whole dependency graph, with each module imported exactly
once. That avoids both a duplicate-module warning and a subtler hazard: the
two modes declare their own internal functions with some shared names
(their public entry points are still uniquely named) that would otherwise
silently shadow one another, depending on import order, if combined by
hand.

## Usage

```xml
<xsl:import href="src/xdm-persistence.xsl"/>

<xsl:variable name="value" as="item()*" select="map { 'a': 1, 'b': (2, 3) }"/>
<xsl:variable name="xml" as="document-node()" select="xdm:serialize($value)"/>
<xsl:variable name="restored" as="item()*" select="xdm:parse($xml)"/>
```

String in/out, for when you need actual markup text rather than a node:

```xquery
xdm:serialize-to-string($value) as xs:string
xdm:parse-string($xml) as item()*
```

Writing to and reading from a file:

```xml
<xsl:result-document href="data.xml" indent="no">
  <xsl:sequence select="xdm:serialize($value)"/>
</xsl:result-document>

<!-- later, possibly in a separate run -->
<xsl:sequence select="xdm:parse(doc('data.xml'))"/>
```

**Always serialize with `indent="no"`** when writing a persisted file -
`indent="no"` is the serializer default, but it's worth setting explicitly
and never overriding. `indent="yes"` inserts whitespace-only text nodes
between adjacent element-only children that had none in the original value,
and those extra text nodes come back as real content on `xdm:parse()` -
silently breaking `deep-equal` against the original for any node with
element-only children, with no error to warn you. If you want a persisted
file to actually be readable, use [xdm-viewer](https://github.com/pgfearo/xdm-viewer)
to view it rather than pretty-printing the `xdm:` XML itself.

## Example

`examples/demo.xsl` writes a sample value to disk (`mode=write`) and reads it
back in a separate invocation (`mode=read`), to demonstrate actual
persistence rather than an in-process round trip:

```sh
java -jar saxon.jar -xsl:examples/demo.xsl -it mode=write
java -jar saxon.jar -xsl:examples/demo.xsl -it mode=read
```

`examples/demo-refs.xsl` is the same idea for the reference-preserving mode:
two real files (`ref-doc1.xml`/`ref-doc2.xml`) are loaded and referenced —
including the same node twice, and a second node from the same document —
written to disk, then read back to confirm identity, cross-reference axis
navigation, and `base-uri()` restoration all still hold:

```sh
java -jar saxon.jar -xsl:examples/demo-refs.xsl -it mode=write
java -jar saxon.jar -xsl:examples/demo-refs.xsl -it mode=read
```

(`.vscode/tasks.json` has matching VS Code tasks if you're using the XSLT
extension with `XSLT.tasks.saxonJar` configured.)

## Tests

`tests/` holds round-trip tests: build a value, serialize it, parse that
back, serialize the result again, and check the two serializations are
deep-equal. `test-refs-roundtrip.xsl` checks the reference-preserving mode's
own guarantees directly instead — node identity via `is`, axis navigation
across independently-referenced nodes, and that no `xdm:key` or other marker
ever appears in a resolved node.

```sh
SAXON_JAR=/path/to/saxon-he-12.jar tests/run.sh
```

## Requirements

An XSLT 3.0 / XPath 3.1 processor with maps, arrays and higher-order
function support — e.g. Saxon Home Edition or above, 9.8+. `xsltproc`
(libxslt) only implements XSLT 1.0 and cannot run this.

## Known limitations

- `xs:NOTATION` values degrade to `xs:untypedAtomic` on parse — XPath has no
  cast constructor for `NOTATION`, so it can't be reconstructed from its
  lexical form alone.
- Function items other than maps and arrays (inline functions, named function
  references, partial applications) are not supported — `xdm:serialize` fails
  with `FOTY0013` if one appears in the value.
- A `document-node()` referenced directly in
  [reference-preserving mode](#reference-preserving-mode) doesn't preserve
  identity between two direct references to it (nodes *within* a document
  are unaffected) — see that section for why.
