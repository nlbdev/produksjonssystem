<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no" exclude-result-prefixes="#all"/>
    
    <xsl:param name="output-dir" as="xs:string"/>
    <xsl:variable name="outputDir" select="concat($output-dir, if (ends-with($output-dir, '/')) then '' else '/')" as="xs:string"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="test">
        <xsl:param name="context" as="element()"/>
        <_ xmlns="">
            <xsl:for-each select="$context">
                <xsl:call-template name="split"/>
            </xsl:for-each>
        </_>
    </xsl:template>
    
    <xsl:template match="/*">
        <xsl:variable name="results" as="element()*">
            <xsl:call-template name="split"/>
        </xsl:variable>
        
        <xsl:for-each select="$results">
            <xsl:variable name="target-uri" select="resolve-uri(@href, $outputDir)"/>
                <xsl:result-document href="{$target-uri}"
                                     indent="no"
                                     method="xhtml"
                                     include-content-type="no"
                                     exclude-result-prefixes="#all">
                    <xsl:text disable-output-escaping="yes">
&lt;!DOCTYPE html&gt;</xsl:text>
                    <xsl:sequence select="node()"/>
                </xsl:result-document>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="split">
        <xsl:variable name="source-document" select="/*" as="element()"/>
        <xsl:variable name="filename" select="replace(replace(base-uri(), '^.*/', ''), '\.[^.]*$', '')" as="xs:string"/>
        <xsl:variable name="zero-padding" select="string-length(string(count(body/*[f:classes(.) = 'html-break-point']) + 1))"/>
        
        <xsl:for-each-group select="body/node()" group-starting-with="*[f:classes(.) = 'html-break-point']">
            <xsl:variable name="content" select="current-group()[not(self::*[f:classes(.) = 'html-break-point'])]" as="node()*"/>
            <xsl:variable name="position" select="position()" as="xs:integer"/>
            
            <!-- determine type -->
            <xsl:variable name="section-start" select="($content[self::*])[1][f:classes(.) = 'section-start']" as="element()?"/>
            <xsl:variable name="preceding-section-start" select="($content[1]/preceding-sibling::*[f:classes(.) = 'section-start'])[last()]" as="element()?"/>
            <xsl:variable name="type" select="(
                f:types($section-start)[not(. = ('cover', 'frontmatter', 'bodymatter', 'backmatter'))],
                f:types($section-start)[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')],
                f:types($preceding-section-start)[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')],
                'chapter'
                )[1]" as="xs:string"/>
            
            <_ xmlns="" href="{concat($filename, '-', f:zero-padded(position(), $zero-padding), '-', $type, '.xhtml')}">
                <!-- newline between xml declaration and html tag -->
                <xsl:text>
</xsl:text>
                
                <!-- copy the html element -->
                <xsl:for-each select="$source-document">
                    <xsl:copy exclude-result-prefixes="#all">
                        <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                        
                        <!-- copy the head element and its metadata -->
                        <xsl:copy-of select="head/preceding-sibling::node()" exclude-result-prefixes="#all"/>
                        <xsl:for-each select="head">
                            <xsl:copy exclude-result-prefixes="#all">
                                <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                                <xsl:copy-of select="node()" exclude-result-prefixes="#all"/>
                                
                                <!--<xsl:text>
        </xsl:text>
                                <xsl:if test="$position gt 1">
                                    <link rel="first" href="{$filenames[1]}"/>
                                <xsl:text>
        </xsl:text>
                                    <link rel="prev" href="{$filenames[$position - 1]}"/>
                                    <xsl:text>
        </xsl:text>
                                </xsl:if>
                                <xsl:if test="$position lt count($filenames)">
                                    <link rel="next" href="{$filenames[$position + 1]}"/>
                                <xsl:text>
        </xsl:text>
                                    <link rel="last" href="{$filenames[last()]}"/>
                                <xsl:text>
        </xsl:text>
                                </xsl:if>-->
                            </xsl:copy>
                        </xsl:for-each>
                        <xsl:copy-of select="head/following-sibling::node() intersect body/preceding-sibling::node()" exclude-result-prefixes="#all"/>
                        <xsl:for-each select="body">
                            <xsl:copy exclude-result-prefixes="#all">
                                <xsl:copy-of select="@* except @id"/>
                                <xsl:copy-of select="$content" exclude-result-prefixes="#all"/>
                            </xsl:copy>
                        </xsl:for-each>
                        <xsl:copy-of select="body/following-sibling::node()" exclude-result-prefixes="#all"/>
                    </xsl:copy>
                </xsl:for-each>
                
                <!-- newline after html closing tag -->
                <xsl:text>
</xsl:text>
            </_>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:function name="f:classes" as="xs:string*">
        <xsl:param name="context" as="element()"/>
        <xsl:sequence select="tokenize($context/@class, '\s')"/>
    </xsl:function>
    
    <xsl:function name="f:types" as="xs:string*">
        <xsl:param name="context" as="element()"/>
        <xsl:sequence select="tokenize($context/@epub:type, '\s')"/>
    </xsl:function>
    
    <xsl:function name="f:zero-padded" as="xs:string">
        <xsl:param name="integer" as="xs:integer"/>
        <xsl:param name="zero-padding" as="xs:integer"/>
        
        <xsl:variable name="result" select="string-join(for $i in (1 to $zero-padding) return '0', '')"/>
        <xsl:variable name="result" select="concat($result, string($integer))"/>
        
        <xsl:value-of select="substring($result,
                                        string-length($result) - $zero-padding + 1,
                                        $zero-padding)"/>
    </xsl:function>
    
</xsl:stylesheet>
