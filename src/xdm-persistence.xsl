<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       The master module: the one file to import for either serialization
       mode. None of the modules below are self-sufficient on their own
       (see each one's own header comment) - this is the single place
       that assembles the whole dependency graph, with each module
       imported exactly once, so there's no diamond-import warning and no
       risk of the two modes' same-named internal helpers shadowing one
       another via import precedence (see xdm-serializer-refs.xsl's and
       xdm-parser-refs.xsl's header comments for why that matters).

       Provides both:
         xdm:serialize / xdm:parse                     - the default,
           deep-equal-only mode (xdm-serializer.xsl / xdm-parser.xsl).
         xdm:serialize-with-refs / xdm:parse-with-refs  - the opt-in,
           reference-preserving mode (xdm-serializer-refs.xsl /
           xdm-parser-refs.xsl), a distinct format from the default mode
           that also preserves node identity and axis navigation across
           references into the same source document.
  -->

  <xsl:import href="xdm-types.xsl"/>
  <xsl:import href="xdm-serializer-common.xsl"/>
  <xsl:import href="xdm-parser-common.xsl"/>
  <xsl:import href="xdm-serializer.xsl"/>
  <xsl:import href="xdm-parser.xsl"/>
  <xsl:import href="xdm-serializer-refs.xsl"/>
  <xsl:import href="xdm-parser-refs.xsl"/>

</xsl:stylesheet>
