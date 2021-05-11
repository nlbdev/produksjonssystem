<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:f="#" xpath-default-namespace="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">
   <xsl:output method="xhtml" indent="no" include-content-type="no"/>
   <xsl:template match="@* | node()" mode="#all">
      <xsl:copy copy-namespaces="no" exclude-result-prefixes="#all">
         <xsl:apply-templates select="@* | node()" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="span[@class='lic']">
      <xsl:apply-templates />
      <xsl:if test="exists(following-sibling::node()[1][matches(name(), 'span')])">
         <xsl:text> </xsl:text>
      </xsl:if>
   </xsl:template>
</xsl:stylesheet>
