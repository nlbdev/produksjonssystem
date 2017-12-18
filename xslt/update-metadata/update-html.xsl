<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes" method="xml"/>
    
    <xsl:param name="html_head" required="yes"/>
    
    <xsl:template match="/html">
        <xsl:variable name="current" select="head" as="element()"/>
        <xsl:variable name="new" select="document($html_head)/*" as="element()"/>
        
        <xsl:choose>
            <xsl:when test="f:diff($current, $new)">
                <xsl:copy>
                    <xsl:copy-of select="$new/namespace::*"/>
                    <xsl:copy-of select="@*"/>
                    <xsl:for-each select="$new">
                        <xsl:copy>
                            <xsl:copy-of select="@* | node()"/>
                            <meta name="dcterms:modified" content="{format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y]-[M]-[D]T[H]:[m]:[s]Z')}"/>
                            <xsl:copy-of select="$current/(* except (title | meta))"/>
                        </xsl:copy>
                    </xsl:for-each>
                    <xsl:copy-of select="* except head"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="f:diff" as="xs:boolean">
        <xsl:param name="current" as="element()"/>
        <xsl:param name="new" as="element()"/>
        
        <xsl:variable name="current-meta" select="$current/(title, meta[not(@name='dcterms:modified')])"/>
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
                    <xsl:message select="concat('Metadata has changed: ', string-join(($a,$b)/(@name, @http-equiv, @charset, name())[1],' or '))"/>
                    <xsl:message select="$a"/>
                    <xsl:message select="$b"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- false if any of the assertions are false -->
        <xsl:value-of select="$result = false()"/>
    </xsl:function>
    
</xsl:stylesheet>
