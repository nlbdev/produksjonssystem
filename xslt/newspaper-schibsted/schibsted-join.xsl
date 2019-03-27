<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.infomaker.se/npexchange/3.5"
                xpath-default-namespace="http://www.infomaker.se/npexchange/3.5"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:param name="files" as="xs:string"/>     <!-- example: Aftenposten_65634.xml,Aftenposten_65635.xml,Aftenposten_65954.xml -->
    <xsl:param name="basepath" as="xs:string"/>  <!-- example: /tmp/foo/avisfeeder/2019-03-19 -->

    <xsl:template name="main">
        <xsl:param name="files_test" as="xs:string?"/>
        <xsl:variable name="files" select="if ($files_test) then $files_test else $files"/>
        
        <!-- split $files -->
        <xsl:variable name="files" select="tokenize($files, ',')"/>
        <xsl:variable name="files" select="for $file in ($files) return if ($file != '') then $file else ()"/>
        
        
        <!-- make sure that $basepath is a file URI -->
        <xsl:variable name="basepath" select="if (not(starts-with($basepath, 'file:'))) then concat('file:', $basepath) else $basepath"/>
        <xsl:variable name="basepath" select="if (not(ends-with($basepath, '/'))) then concat($basepath, '/') else $basepath"/>
        
        
        <!-- load documents from disk -->
        <xsl:variable name="documents" select="for $file in ($files) return document(resolve-uri($file, $basepath))/*" as="element()*"/>
        
        
        <!-- join documents -->
        <xsl:choose>
            <xsl:when test="count($documents) = 0">
                <npexchange xmlns="http://www.infomaker.se/npexchange/3.5"/>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:variable name="first" select="$documents[1]"/>
                <xsl:variable name="remaining" select="$documents[position() gt 1]"/>
                <xsl:for-each select="$first">
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        
                        <xsl:copy-of select="origin"/>
                        <xsl:copy-of select="article"/>
                        <xsl:copy-of select="$remaining/article"/>
                    </xsl:copy>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>
