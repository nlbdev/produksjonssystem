<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nlbprod="http://www.nlb.no/production"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:opf="http://www.idpf.org/2007/opf"
    xmlns="http://www.idpf.org/2007/opf"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:param name="book-id" required="yes"/>
    <xsl:param name="book-id-rows" required="yes"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="qdbapi">
        <xsl:copy>
            <xsl:apply-templates select="@* | table"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="table">
        <xsl:copy>
            <xsl:apply-templates select="@* | name | desc | original | fields | lastluserid | lusers | records"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="original">
        <xsl:copy>
            <xsl:apply-templates select="@* | table_id | app_id | cre_date | mod_date | def_sort_fid | def_sort_order | key_fid | single_record_name | plural_record_name"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="records">
        <xsl:copy>
            <xsl:apply-templates select="@* | record"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="record">
        <xsl:variable name="book-ids" select="distinct-values(for $f in f[@id = tokenize($book-id-rows,'\s+')] return (if ($f/normalize-space(text())) then $f/normalize-space(text()) else ()))"/>
        <xsl:if test="$book-id = $book-ids">
            <xsl:copy-of select="."/>
        </xsl:if>
    </xsl:template>
    
</xsl:stylesheet>
