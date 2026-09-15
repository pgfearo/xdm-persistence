<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Reference-preserving serialization: a distinct, opt-in mode from
       xdm-serializer.xsl/xdm-parser.xsl, producing a different format
       (xdm:context, not a bare xdm:sequence) that documents from parse
       either format do not read.

       A node whose root() is a document-node() is persisted by reference
       into a pooled copy of its whole document, rather than as an inline
       copy - preserving node identity (the same node referenced twice
       comes back as the same node) and full axis navigation (ancestor::,
       following-sibling::, etc. all work on the reconstructed node, since
       it's a real position within a genuinely reconstructed document, not
       a synthetic fragment). A node whose root() is NOT a document-node()
       (a one-off constructed fragment, with no document worth pooling) is
       embedded inline exactly as xdm-serializer.xsl already does.
  -->

  <xsl:import href="xdm-types.xsl"/>
  <xsl:import href="xdm-serializer-common.xsl"/>

  <!-- Pass 1: every node-valued item anywhere in $value whose root() is a
       document-node() - i.e. every reference that needs to be resolved
       against a pooled document rather than embedded inline. The same
       node instance appears once per occurrence it's found at (not
       deduplicated here); xdm:distinct-anchors below does the
       deduplication, by anchor identity, for pass 2's annotation step.
       Map keys are never node()s (xs:anyAtomicType only), so only values
       need visiting. -->
  <xsl:function name="xdm:collect-doc-refs" as="node()*">
    <xsl:param name="value" as="item()*"/>
    <xsl:for-each select="$value">
      <xsl:sequence select="xdm:collect-doc-refs-from-item(.)"/>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="xdm:collect-doc-refs-from-item" as="node()*">
    <xsl:param name="item" as="item()"/>
    <xsl:choose>
      <xsl:when test="$item instance of map(*)">
        <xsl:variable name="m" as="map(*)" select="$item"/>
        <xsl:sequence select="for $k in map:keys($m) return xdm:collect-doc-refs($m($k))"/>
      </xsl:when>
      <xsl:when test="$item instance of array(*)">
        <xsl:variable name="a" as="array(*)" select="$item"/>
        <xsl:sequence select="for $i in 1 to array:size($a) return xdm:collect-doc-refs($a($i))"/>
      </xsl:when>
      <xsl:when test="$item instance of node()">
        <xsl:if test="root($item) instance of document-node()">
          <xsl:sequence select="$item"/>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise/> <!-- atomic value: nothing to collect -->
    </xsl:choose>
  </xsl:function>

  <!-- The nearest addressable "anchor" for a node: itself if it's already
       an element (elements always get their own xdm:key when pooled),
       otherwise its owning element (an attribute, namespace node, text,
       comment or PI that's a child of an element - parent::* also covers
       attribute/namespace nodes, since "parent" for those means "owning
       element" per XDM), otherwise the containing document node itself
       (a comment/PI that's a direct child of the document node, outside
       the root element - document nodes can't carry an xdm:key, so that
       case is addressed relative to the pooled document itself rather
       than via key lookup). -->
  <xsl:function name="xdm:anchor-of" as="node()">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="
      if ($node instance of element()) then $node
      else if (exists($node/parent::*)) then $node/parent::*
      else root($node)"/>
  </xsl:function>

  <!-- How to find $node starting from xdm:anchor-of($node):
       '0'          - the anchor element is itself the referenced node
       '@Q{uri}local' - an attribute, addressed by EQName (immune to
                        which prefix, if any, the source document used)
       '{prefix}uri'  - a namespace node (prefix is '' for the default
                        namespace)
       a plain integer - the 1-based ordinal position of the node among
                        ALL child nodes (any kind) of its anchor - works
                        identically whether the anchor is an element or
                        (for the document-level fallback above) a
                        document node, since preceding-sibling::node()
                        behaves the same either way. -->
  <xsl:function name="xdm:position-code" as="xs:string">
    <xsl:param name="node" as="node()"/>
    <xsl:choose>
      <xsl:when test="$node instance of element()">
        <xsl:sequence select="'0'"/>
      </xsl:when>
      <xsl:when test="$node instance of attribute()">
        <xsl:sequence select="'@' || xdm:eqname-of(node-name($node))"/>
      </xsl:when>
      <xsl:when test="$node instance of namespace-node()">
        <xsl:sequence select="'{' || name($node) || '}' || string($node)"/>
      </xsl:when>
      <xsl:otherwise> <!-- text, comment or processing-instruction -->
        <xsl:sequence select="string(count($node/preceding-sibling::node()) + 1)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:eqname-of" as="xs:string">
    <xsl:param name="qname" as="xs:QName"/>
    <xsl:sequence select="'Q{' || namespace-uri-from-QName($qname) || '}' || local-name-from-QName($qname)"/>
  </xsl:function>

  <!-- The distinct (by identity) anchor nodes for a set of references -
       exactly the set of nodes that need an xdm:key added when the pool
       document they belong to is copied. The '|' union operator
       deduplicates by node identity and returns document order, so a
       node referenced many times (or several references sharing one
       anchor) only appears once. -->
  <xsl:function name="xdm:distinct-anchors" as="node()*">
    <xsl:param name="refs" as="node()*"/>
    <xsl:variable name="anchors" as="node()*" select="for $r in $refs return xdm:anchor-of($r)"/>
    <xsl:sequence select="$anchors | $anchors"/>
  </xsl:function>

  <!-- Identifies a pooled document itself, for the document-level
       fallback addressing case (see xdm:anchor-of) where there's no
       anchor element to carry an xdm:key: the document's own URI when it
       has one (e.g. read via doc()), otherwise a generated id stable for
       the lifetime of this serialize() call. -->
  <xsl:function name="xdm:doc-id" as="xs:string">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="
      let $uri := document-uri($doc)
      return if (exists($uri) and string-length($uri) gt 0) then $uri else generate-id($doc)"/>
  </xsl:function>

  <!-- The <xdm:node-ref> marker that replaces an inline copy of $node in
       the xdm:sequence part of the output. Two addressing forms:
       key+pos for the common case (anchor is an element, found via
       xsl:key against the pool on parse), doc+pos for the document-level
       fallback (anchor is a document node, which can't carry an xdm:key,
       so it's addressed by the pool entry's own id instead). -->
  <xsl:function name="xdm:build-node-ref" as="element(xdm:node-ref)">
    <xsl:param name="node" as="node()"/>
    <xsl:variable name="anchor" as="node()" select="xdm:anchor-of($node)"/>
    <xsl:variable name="pos" as="xs:string" select="xdm:position-code($node)"/>
    <xsl:choose>
      <xsl:when test="$anchor instance of element()">
        <xdm:node-ref key="{generate-id($anchor)}" pos="{$pos}"/>
      </xsl:when>
      <xsl:otherwise>
        <xdm:node-ref doc="{xdm:doc-id($anchor)}" pos="{$pos}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- The distinct (by identity) documents referenced anywhere in $refs -
       one pool entry per document, however many nodes within it are
       actually referenced. -->
  <xsl:function name="xdm:distinct-pool-docs" as="document-node()*">
    <xsl:param name="refs" as="node()*"/>
    <xsl:variable name="roots" as="document-node()*" select="for $r in $refs return root($r)"/>
    <xsl:sequence select="$roots | $roots"/>
  </xsl:function>

  <!-- Pass 2: a structural copy of $node, adding xdm:key="{generate-id(.)}"
       to every element that's a member of $anchorIds (a set built from
       xdm:distinct-anchors, keyed by generate-id() for an O(1) test per
       element rather than a linear scan). Everything else - the element's
       own name, namespaces and attributes, and every non-element node -
       is copied through completely unchanged; only elements can carry
       the marker, and only elements that are actually anchors get one. -->
  <xsl:function name="xdm:copy-with-keys" as="node()*">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="anchorIds" as="map(*)"/>
    <xsl:choose>
      <xsl:when test="$node instance of element()">
        <xsl:for-each select="$node">
          <xsl:copy>
            <xsl:if test="map:contains($anchorIds, generate-id(.))">
              <xsl:attribute name="xdm:key" select="generate-id(.)"/>
            </xsl:if>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="node()">
              <xsl:sequence select="xdm:copy-with-keys(., $anchorIds)"/>
            </xsl:for-each>
          </xsl:copy>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="$node"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- The whole xdm:documents pool: one xdm:pool-doc per distinct
       referenced document (id = xdm:doc-id, the document's own URI when
       it has one), each holding an annotated copy of that document's
       children. -->
  <xsl:function name="xdm:build-documents-pool" as="element(xdm:documents)">
    <xsl:param name="refs" as="node()*"/>
    <xsl:variable name="anchors" as="node()*" select="xdm:distinct-anchors($refs)"/>
    <xsl:variable name="anchorIds" as="map(*)" select="map:merge($anchors ! map:entry(generate-id(.), true()))"/>
    <xdm:documents>
      <xsl:for-each select="xdm:distinct-pool-docs($refs)">
        <xdm:pool-doc id="{xdm:doc-id(.)}">
          <xsl:for-each select="./node()">
            <xsl:sequence select="xdm:copy-with-keys(., $anchorIds)"/>
          </xsl:for-each>
        </xdm:pool-doc>
      </xsl:for-each>
    </xdm:documents>
  </xsl:function>

</xsl:stylesheet>
