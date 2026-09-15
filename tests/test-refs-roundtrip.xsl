<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                xmlns:ex="http://example.com/ex"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Round-trip test for the reference-preserving mode
       (xdm:serialize-with-refs / xdm:parse-with-refs), a distinct opt-in
       format from xdm-serializer.xsl/xdm-parser.xsl's deep-equal-only
       contract. Unlike the other tests here, deep-equal is not the goal:
       this mode's whole point is node *identity* and axis navigation
       across independently-referenced nodes from the same source
       document, so each requirement is checked directly rather than via
       a single deep-equal call.

       Checks: the same node referenced twice comes back as the same node
       (the `is` operator, not just deep-equal); ancestor:: and
       following-sibling:: work across two separately-referenced nodes;
       qualified and unqualified attributes and a namespace node resolve
       correctly; comments resolve both as a child of an element and as a
       direct child of the document node (the doc-level fallback case); a
       document-node() itself, referenced directly, resolves to a real
       document node, and - via xdm:build-whole-docs-map, one document
       node built per pool entry and shared by every reference into it
       within one xdm:parse-with-refs call - comes back identical across
       two such direct references, with root() of an ordinary element
       reference lining up with it too; and - the reason this mode was
       reworked to use positional paths instead of an xdm:key marker
       attribute - no xdm:key (or any other added attribute) ever appears
       anywhere in the resolved value.
  -->

  <xsl:import href="../src/xdm-persistence.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="src" as="document-node()">
    <xsl:document>
      <xsl:comment>doc-level comment before the root element</xsl:comment>
      <people:family xmlns:ex="http://example.com/ex" ex:role="head" id="f1">
        <people:parent><people:child/></people:parent>
        <people:sibling><xsl:comment>only child, no descendants</xsl:comment></people:sibling>
      </people:family>
    </xsl:document>
  </xsl:variable>

  <xsl:variable name="targetElement" as="element()" select="$src/people:family/people:parent/people:child"/>
  <xsl:variable name="plainAttr" as="attribute()" select="$src/people:family/@id"/>
  <xsl:variable name="nsAttr" as="attribute()" select="$src/people:family/@ex:role"/>
  <xsl:variable name="elementComment" as="comment()" select="$src/people:family/people:sibling/comment()"/>
  <xsl:variable name="docComment" as="comment()" select="$src/comment()"/>

  <xsl:variable name="sampleValue" as="map(*)" select="
    map {
      'ref1': $targetElement,
      'ref2': $targetElement,
      'attr': $plainAttr,
      'nsAttr': $nsAttr,
      'elementComment': $elementComment,
      'docComment': $docComment,
      'wholeDoc': $src,
      'wholeDoc2': $src
    }"/>

  <xsl:variable name="serialized" as="document-node()" select="xdm:serialize-with-refs($sampleValue)"/>
  <xsl:variable name="restored" as="map(*)" select="xdm:parse-with-refs($serialized)"/>

  <xsl:variable name="checks" as="map(xs:string, xs:boolean)" select="
    map {
      'same node referenced twice comes back identical':
        $restored?ref1 is $restored?ref2,
      'ancestor:: navigates from the referenced node up to its family':
        $restored?ref1/ancestor::people:family is $restored?attr/..,
      'following-sibling:: connects two independently-referenced nodes':
        $restored?ref1/../following-sibling::people:sibling is $restored?elementComment/..,
      'unqualified attribute resolves with correct value':
        $restored?attr instance of attribute() and string($restored?attr) eq 'f1',
      'namespaced attribute resolves with correct namespace and value':
        namespace-uri($restored?nsAttr) eq 'http://example.com/ex' and string($restored?nsAttr) eq 'head',
      'comment inside an element resolves correctly':
        $restored?elementComment instance of comment()
          and string($restored?elementComment) eq 'only child, no descendants',
      'document-level comment (outside the root element) resolves correctly':
        $restored?docComment instance of comment()
          and string($restored?docComment) eq 'doc-level comment before the root element',
      'whole document-node() reference resolves to a real document, correct root':
        $restored?wholeDoc instance of document-node()
          and local-name($restored?wholeDoc/*) eq 'family',
      'two direct references to the same document-node() come back identical':
        $restored?wholeDoc is $restored?wholeDoc2,
      'root() of an ordinary element reference lines up with a direct reference to its document':
        $restored?ref1 => root() is $restored?wholeDoc,
      'no xdm:key (or any other marker) appears anywhere in a resolved node':
        empty($restored?ref1/ancestor-or-self::*/@*[node-name(.) eq QName('http://deltaxignia.com/ns/xdm-persistence', 'xdm:key')])
    }"/>

  <xsl:variable name="failures" as="xs:string*" select="map:keys($checks)[not($checks(.))]"/>

  <xsl:template name="xsl:initial-template">
    <xsl:choose>
      <xsl:when test="empty($failures)">
        <xsl:message select="'PASS: reference-preserving round-trip (' || count(map:keys($checks)) || ' checks)' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$failures">
          <xsl:message select="'FAIL: ' || . || '&#10;'"/>
        </xsl:for-each>
        <xsl:message select="'--- serialized ---' || '&#10;' || serialize($serialized, map{'method':'xml', 'indent': true()}) || '&#10;'"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
