<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.idpf.org/2007/opf"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:output indent="no" method="xml" exclude-result-prefixes="#all"/>

    <xsl:param name="cover-id" as="xs:string"/>

    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!-- replace existing metadata if it exists -->
    <xsl:template match="metadata/meta[@name='cover']">
        <xsl:call-template name="create-meta-cover"/>
    </xsl:template>

    <!-- insert new metadata if it does not exist -->
    <xsl:template match="metadata">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>

            <xsl:if test="not(exists(meta[@name='cover']))">
                <xsl:call-template name="create-meta-cover"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

    <!-- template for creating the metadata -->
    <xsl:template name="create-meta-cover">
        <xsl:text>    </xsl:text>
        <meta name="cover" content="{$cover-id}"/>
        <xsl:text>
    </xsl:text>
    </xsl:template>

    <!-- update manifest item properties -->
    <xsl:template match="manifest/item">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @properties"/>

            <xsl:variable name="properties" select="tokenize(@properties, '\s+')[not(. = 'cover-image')]" as="xs:string*"/>  <!-- all properties except the cover-image property -->
            <xsl:variable name="properties" select="(if (@id = $cover-id) then 'cover-image' else (), $properties)" as="xs:string*"/>  <!-- conditionally add the cover-image property -->

            <xsl:if test="count($properties)">
                <xsl:attribute name="properties" select="string-join($properties, ' ')"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
