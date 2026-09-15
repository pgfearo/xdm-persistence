<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="xsl map array"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Reads back the xdm:context tree produced by xdm-serializer-refs.xsl.
       A distinct, opt-in mode from xdm-parser.xsl - does not read that
       format's plain xdm:sequence documents, and xdm-parser.xsl does not
       read this one's.

       Node identity is preserved for repeated references (xdm:parse(a) is
       xdm:parse(b) holds when a and b referenced the same original node),
       since every reference resolves against the one already-parsed pool
       document rather than being copied. A reference is resolved by
       walking a plain positional path (see xdm-serializer-refs.xsl's
       xdm:node-path-steps) down an untouched, unannotated copy of the
       original document - nothing was ever written into the pool to find
       a node, so a resolved node is indistinguishable from the original
       (no xdm:key or other marker attribute ever appears in it).

       Known limitation: a document-node() referenced directly (as opposed
       to a node within one) is reconstructed fresh on every resolution,
       since there is no pre-existing document-node wrapper in the pool to
       hand back - so identity is not preserved between two direct
       references to the very same document-node(). Identity for every
       node *within* a document is unaffected by this.
  -->

  <xsl:import href="xdm-types.xsl"/>
  <xsl:import href="xdm-parser-common.xsl"/>

  <xsl:function name="xdm:parse-with-refs" as="item()*">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="xdm:parse-item-seq($doc/xdm:context/xdm:sequence/xdm:item)"/>
  </xsl:function>

  <xsl:function name="xdm:parse-item-seq" as="item()*">
    <xsl:param name="items" as="element(xdm:item)*"/>
    <xsl:for-each select="$items">
      <xsl:sequence select="xdm:parse-item(.)"/>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="xdm:parse-item" as="item()*">
    <xsl:param name="item" as="element(xdm:item)"/>
    <xsl:variable name="payload" as="element()" select="$item/*[1]"/>
    <xsl:choose>
      <xsl:when test="$payload/self::xdm:node-ref">
        <xsl:sequence select="xdm:resolve-node-ref($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:atomic">
        <xsl:sequence select="xdm:parse-atomic($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:map">
        <xsl:sequence select="xdm:parse-map($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:array">
        <xsl:sequence select="xdm:parse-array($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:text">
        <xsl:value-of select="string($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:comment">
        <xsl:comment><xsl:value-of select="string($payload)"/></xsl:comment>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:pi">
        <xsl:processing-instruction name="{string($payload/@name)}">
          <xsl:value-of select="string($payload)"/>
        </xsl:processing-instruction>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:attribute">
        <xsl:sequence select="xdm:parse-attribute($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:namespace">
        <xsl:sequence select="xdm:parse-namespace($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:document">
        <xsl:document>
          <xsl:sequence select="$payload/node()"/>
        </xsl:document>
      </xsl:when>
      <xsl:otherwise> <!-- a plain copied element node -->
        <xsl:sequence select="$payload"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:parse-atomic" as="xs:anyAtomicType">
    <xsl:param name="atomicEl" as="element(xdm:atomic)"/>
    <xsl:variable name="type" as="xs:string" select="xdm:resolve-type-name($atomicEl/@type)"/>
    <xsl:sequence select="
      if ($type eq 'xs:QName') then xdm:cast-qname($atomicEl/@uri, string($atomicEl))
      else xdm:cast-atomic($type, string($atomicEl))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-map" as="map(*)">
    <xsl:param name="mapEl" as="element(xdm:map)"/>
    <xsl:sequence select="
      map:merge(
        for $entry in $mapEl/xdm:entry
        return map:entry(xdm:parse-key($entry), xdm:parse-item-seq($entry/xdm:item)))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-key" as="xs:anyAtomicType">
    <xsl:param name="entry" as="element(xdm:entry)"/>
    <xsl:variable name="keyType" as="xs:string" select="xdm:resolve-type-name($entry/@key-type)"/>
    <xsl:sequence select="
      if ($keyType eq 'xs:QName') then xdm:cast-qname($entry/@key-uri, string($entry/@key))
      else xdm:cast-atomic($keyType, string($entry/@key))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-array" as="array(*)">
    <xsl:param name="arrayEl" as="element(xdm:array)"/>
    <xsl:sequence select="
      fold-left($arrayEl/xdm:member, array{},
        function($acc, $m) { array:append($acc, xdm:parse-item-seq($m/xdm:item)) })"/>
  </xsl:function>

  <!-- Resolves one <xdm:node-ref doc="..."><xdm:step pos="..."/>...</xdm:node-ref>
       marker back to the actual node it addresses, per
       xdm-serializer-refs.xsl's xdm:node-path-steps scheme: find the pool
       entry for @doc, then walk its <xdm:step> children in order,
       descending one level per step. -->
  <xsl:function name="xdm:resolve-node-ref" as="node()">
    <xsl:param name="ref" as="element(xdm:node-ref)"/>
    <xsl:variable name="poolDoc" as="element(xdm:pool-doc)" select="xdm:pool-doc-by-id(string($ref/@doc), root($ref))"/>
    <xsl:variable name="steps" as="xs:string*" select="$ref/xdm:step/string(@pos)"/>
    <xsl:sequence select="xdm:navigate-from-doc($poolDoc, $steps)"/>
  </xsl:function>

  <xsl:function name="xdm:pool-doc-by-id" as="element(xdm:pool-doc)">
    <xsl:param name="id" as="xs:string"/>
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="($doc/xdm:context/xdm:documents/xdm:pool-doc[@id = $id])[1]"/>
  </xsl:function>

  <!-- The outermost step, if any, selects among the pool entry's own
       node() children (xdm:pool-doc/node() corresponds 1:1, in order, to
       the original document's own node() children, since the pool was
       built with a plain xsl:copy-of). Zero steps means the reference was
       to the document-node() itself - reconstructed fresh, see the header
       comment's note on identity for that one case. -->
  <xsl:function name="xdm:navigate-from-doc" as="node()">
    <xsl:param name="poolDoc" as="element(xdm:pool-doc)"/>
    <xsl:param name="steps" as="xs:string*"/>
    <xsl:choose>
      <xsl:when test="empty($steps)">
        <xsl:document>
          <xsl:sequence select="$poolDoc/node()"/>
        </xsl:document>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="first" as="node()" select="($poolDoc/node())[xs:integer($steps[1])]"/>
        <xsl:sequence select="xdm:navigate-from-node($first, subsequence($steps, 2))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Every subsequent step descends one level further from $node: an
       ordinal step moves to ($node/node())[pos], an '@'/'{' step (only
       ever the last one) selects an attribute or namespace node of
       $node - which must therefore be the last step, since neither kind
       has children of its own. -->
  <xsl:function name="xdm:navigate-from-node" as="node()">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="steps" as="xs:string*"/>
    <xsl:choose>
      <xsl:when test="empty($steps)">
        <xsl:sequence select="$node"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="step" as="xs:string" select="$steps[1]"/>
        <xsl:variable name="next" as="node()" select="
          if (starts-with($step, '@')) then xdm:find-attribute-by-eqname($node, substring($step, 2))
          else if (starts-with($step, '{')) then xdm:find-namespace-by-marker($node, $step)
          else ($node/node())[xs:integer($step)]"/>
        <xsl:sequence select="xdm:navigate-from-node($next, subsequence($steps, 2))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- $eqname is the step's code with its leading '@' already stripped,
       e.g. 'Q{http://example.com/foo}attr' or 'Q{}plain'. -->
  <xsl:function name="xdm:find-attribute-by-eqname" as="attribute()">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="eqname" as="xs:string"/>
    <xsl:variable name="uri" as="xs:string" select="substring-before(substring-after($eqname, 'Q{'), '}')"/>
    <xsl:variable name="local" as="xs:string" select="substring-after($eqname, '}')"/>
    <xsl:sequence select="($node/@*[namespace-uri(.) eq $uri and local-name(.) eq $local])[1]"/>
  </xsl:function>

  <!-- $marker is the full step code, e.g. '{foo}http://example.com/foo'. -->
  <xsl:function name="xdm:find-namespace-by-marker" as="namespace-node()">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="marker" as="xs:string"/>
    <xsl:variable name="prefix" as="xs:string" select="substring-before(substring-after($marker, '{'), '}')"/>
    <xsl:sequence select="($node/namespace::*[name() eq $prefix])[1]"/>
  </xsl:function>

</xsl:stylesheet>
