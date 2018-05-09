<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:f="#"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no"/>
    
    <xsl:param name="opf_metadata" required="yes"/>
    <xsl:param name="modified" as="xs:string?"/>
    
    <xsl:template match="/package">
        <xsl:variable name="current" select="metadata" as="element()"/>
        <xsl:variable name="new" select="document($opf_metadata)/*" as="element()"/>
        
        <xsl:text><![CDATA[
]]></xsl:text>
        <xsl:choose>
            <xsl:when test="f:diff($current, $new)">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="$new/namespace::*" exclude-result-prefixes="#all"/>
                    <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    <xsl:copy-of select="$new/@prefix" exclude-result-prefixes="#all"/>
                    <xsl:attribute name="unique-identifier" select="'pub-identifier'"/>
                    <xsl:for-each select="$new">
                        <xsl:text><![CDATA[
    ]]></xsl:text>
                        <xsl:copy exclude-result-prefixes="#all">
                            <xsl:copy-of select="@* except @prefix" exclude-result-prefixes="#all"/>
                            <xsl:for-each select="node() except (* | comment())[last()]/following-sibling::node()">
                                <xsl:choose>
                                    <xsl:when test="self::dc:identifier">
                                        <xsl:copy exclude-result-prefixes="#all">
                                            <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                                            <xsl:attribute name="id" select="'pub-identifier'"/>
                                            <xsl:copy-of select="node()" exclude-result-prefixes="#all"/>
                                        </xsl:copy>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>
                            <xsl:text><![CDATA[
        
        ]]></xsl:text>
                            <meta property="dcterms:modified"><xsl:value-of select="if ($modified) then $modified else format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]-[M00]-[D00]T[H00]:[m00]:[s00]Z')"/></meta>
                            <xsl:text><![CDATA[
    ]]></xsl:text>
                        </xsl:copy>
                    </xsl:for-each>
                    <xsl:copy-of select="node() except metadata/(. | preceding-sibling::node())" exclude-result-prefixes="#all"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="f:diff" as="xs:boolean">
        <xsl:param name="current" as="element()"/>
        <xsl:param name="new" as="element()"/>
        
        <xsl:variable name="current-meta" select="$current/*[not(@property='dcterms:modified')]"/>
        <xsl:variable name="new-meta" select="$new/*"/>
        
        <!-- assertions -->
        <xsl:variable name="result" as="xs:boolean*">
            <!-- must be exactly the same amount of elements (excluding dcterms:modified) -->
            <xsl:sequence select="count($current-meta) = count($new-meta)"/>
            
            <!-- both sets of metadata must be ordered the same way, have the same attributes, and the same values -->
            <xsl:for-each select="1 to count($current-meta)">
                <xsl:variable name="a" select="$current-meta[current()]"/>
                <xsl:variable name="b" select="$new-meta[current()]"/>
                
                <xsl:variable name="ab-diff" as="xs:boolean*">
                    <xsl:sequence select="$a/name() = $b/name()"/>
                    <xsl:sequence select="count($a/*) = count($b/*)"/>
                    <xsl:sequence select="$a/text() eq $b/text()"/>
                    <xsl:sequence select="for $attr in (distinct-values(($a | $b)/@*/name())) return ($a/@*/name() = $attr, $b/@*/name() = $attr, $a/@*[name()=$attr] = $b/@*[name()=$attr])"/>
                </xsl:variable>
                <xsl:sequence select="$ab-diff"/>
                
                <!-- Some messaging for the logs -->
                <xsl:if test="false() = $ab-diff">
                    <xsl:message select="concat('Metadata has changed: ', string-join(($a,$b)/(@property, name())[1],' or '))"/>
                    <xsl:message select="$a"/>
                    <xsl:message select="$b"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- false if any of the assertions are false -->
        <xsl:value-of select="$result = false()"/>
    </xsl:function>
    
</xsl:stylesheet>
