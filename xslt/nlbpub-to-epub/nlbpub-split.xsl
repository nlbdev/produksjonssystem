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
    <xsl:variable name="outputDir_1" select="concat($output-dir, if (ends-with($output-dir, '/')) then '' else '/')" as="xs:string"/>
    <xsl:variable name="outputDir" select="if (matches($outputDir_1, '^\w+:/')) then $outputDir_1 else concat('file:', $outputDir_1)" as="xs:string"/>
    
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
        <xsl:variable name="original-href" select="replace(base-uri(), '^.*/', '')" as="xs:string"/>
        
        <xsl:variable name="after-split" as="node()*">
            <xsl:call-template name="perform-split"/>
        </xsl:variable>
        
        <xsl:apply-templates mode="post-process" select="$after-split">
            <xsl:with-param name="after-split" select="$after-split" as="node()*" tunnel="yes"/>
            <xsl:with-param name="original-href" select="$original-href" as="xs:string" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template name="perform-split">
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
                        <xsl:copy-of select="head" exclude-result-prefixes="#all"/>
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
    
    <xsl:template match="@src | @href | @data[parent::object] | @altimg | @longdesc" mode="post-process">
        <xsl:param name="after-split" as="node()*" tunnel="yes"/>
        <xsl:param name="original-href" as="xs:string" tunnel="yes"/>
        
        <xsl:choose>
            <xsl:when test="not(contains(., '#'))">
                <!-- does not contain a id reference -->
                <xsl:next-match/>
                
            </xsl:when>
            <xsl:when test="starts-with(., '#') or starts-with(., concat($original-href, '#'))">
                <!-- this is an internal link, we need to update it with the new filename -->
                
                <xsl:variable name="id" select="tokenize(., '#')[2]" as="xs:string"/>
                <xsl:variable name="target-element" select="($after-split//*[@id = $id])[1]" as="element()?"/>
                
                <xsl:variable name="target-href" select="($target-element/ancestor::*[local-name() = '_' and @href])[1]/@href" as="xs:string?"/>
                <xsl:variable name="current-href" select="(ancestor::*[local-name() = '_' and @href])[1]/@href" as="xs:string"/>
                
                <xsl:message select="concat('Reference: ', name(), '=''', ., ''', at /', string-join(for $e in (ancestor-or-self::*) return concat($e/name(), '[', count($e/preceding-sibling::*[name() = $e/name()]), ']'), '/'))"/>
                
                <xsl:choose>
                    <xsl:when test="not($target-href)">
                        <xsl:message select="concat('Could not find target element for ', name(), '=''', ., ''', at /', string-join(for $e in (ancestor-or-self::*) return concat($e/name(), '[', count($e/preceding-sibling::*[name() = $e/name()]), ']'), '/'))"/>
                        <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                    </xsl:when>
                    <xsl:when test="$target-href = $current-href">
                        <xsl:attribute name="{name()}" select="concat('#', $id)" exclude-result-prefixes="#all"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="{name()}" select="concat($target-href, '#', $id)" exclude-result-prefixes="#all"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:when>
            <xsl:otherwise>
                <!-- not an internal link -->
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="head" mode="post-process">
        <xsl:param name="after-split" as="node()*" tunnel="yes"/>
        <xsl:variable name="after-split-elements" select="$after-split[local-name() = '_']" as="element()+"/>
        
        <xsl:variable name="current-href" select="../../@href"/>
        <xsl:variable name="all-hrefs" select="$after-split-elements/@href"/>
        <xsl:variable name="position" as="xs:integer">
            <xsl:for-each select="$all-hrefs">
                <xsl:if test=". = $current-href">
                    <xsl:value-of select="position()"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="start" select="$after-split-elements[position() = 1]/@href" as="xs:string?"/>
        <xsl:variable name="first" select="if ($position gt 1) then $after-split-elements[position() = 1]/@href else ()" as="xs:string?"/>
        <xsl:variable name="prev" select="if ($position gt 1) then $after-split-elements[position() = $position - 1]/@href else ()" as="xs:string?"/>
        <xsl:variable name="next" select="if ($position lt count($after-split-elements)) then $after-split-elements[position() = $position + 1]/@href else ()" as="xs:string?"/>
        <xsl:variable name="last" select="if ($position lt count($after-split-elements)) then $after-split-elements[position() = last()]/@href else ()" as="xs:string?"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
            <xsl:copy-of select="node()" exclude-result-prefixes="#all"/>
            
            <xsl:text>    </xsl:text>
            <xsl:text>
        </xsl:text>
            
            <!--<xsl:if test="$start">
                <link rel="start" href="{$start}"/>
                <xsl:text>
        </xsl:text>
            </xsl:if>-->
            
            <!--<xsl:if test="$first">
                <link rel="first" href="{$first}"/>
                <xsl:text>
        </xsl:text>
            </xsl:if>-->
            
            <xsl:if test="$prev">
                <link rel="prev" href="{$prev}"/>
                <xsl:text>
        </xsl:text>
            </xsl:if>
            
            <xsl:if test="$next">
                <link rel="next" href="{$next}"/>
                <xsl:text>
        </xsl:text>
            </xsl:if>
            
            <!--<xsl:if test="$last">
                <link rel="last" href="{$last}"/>
                <xsl:text>
        </xsl:text>
            </xsl:if>-->
        </xsl:copy>
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
