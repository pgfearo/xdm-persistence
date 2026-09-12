# xdm-persistence

A persistence solution for the XPath 3.1 Data Model (XDM): serialize any XDM
value — nodes, maps, arrays, and atomic values, in any combination or nesting
— to XML, and parse that XML back into an equivalent value.

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
  back to exactly the same type, not just "string/number/boolean".

## Files

| File | Purpose |
|---|---|
| `src/xdm-types.xsl` | Shared vocabulary: the `xdm:` namespace, atomic type-name detection, and lexical cast-back |
| `src/xdm-serializer.xsl` | `xdm:serialize($value)`, `xdm:serialize-to-string($value)` |
| `src/xdm-parser.xsl` | `xdm:parse($doc)`, `xdm:parse-string($xml)` |
| `src/xdm-persistence.xsl` | Single entry point that imports all three of the above |

Import `xdm-persistence.xsl` in your own stylesheets rather than the
individual `xdm-serializer.xsl`/`xdm-parser.xsl` files — those two no longer
import `xdm-types.xsl` themselves, precisely so that importing both of them
together (via `xdm-persistence.xsl`) doesn't trigger a duplicate-module
warning from the processor.

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
<xsl:result-document href="data.xml">
  <xsl:sequence select="xdm:serialize($value)"/>
</xsl:result-document>

<!-- later, possibly in a separate run -->
<xsl:sequence select="xdm:parse(doc('data.xml'))"/>
```

## Example

`examples/demo.xsl` writes a sample value to disk (`mode=write`) and reads it
back in a separate invocation (`mode=read`), to demonstrate actual
persistence rather than an in-process round trip:

```sh
java -jar saxon.jar -xsl:examples/demo.xsl -it mode=write
java -jar saxon.jar -xsl:examples/demo.xsl -it mode=read
```

(`.vscode/tasks.json` has matching VS Code tasks if you're using the XSLT
extension with `XSLT.tasks.saxonJar` configured.)

## Tests

`tests/` holds round-trip tests: build a value, serialize it, parse that
back, serialize the result again, and check the two serializations are
deep-equal.

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
