<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                version="2.0">

    <xsl:output indent="no" include-content-type="no"/>
    <xsl:param name="identifier"/>

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

  <xsl:template match="meta[@name='dc:identifier']">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
        <xsl:attribute name="content" select="$identifier"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
