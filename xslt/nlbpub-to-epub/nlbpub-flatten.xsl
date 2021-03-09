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
    
    <xsl:param name="break-before" select="'cover,volume,part,chapter'" as="xs:string"/>
    <xsl:param name="break-before-in-bodymatter" select="'footnotes,endnotes'" as="xs:string"/>
    
    <xsl:variable name="breakBefore" select="tokenize($break-before, ',')"/>
    <xsl:variable name="breakBeforeInBodymatter" select="tokenize($break-before-in-bodymatter, ',')"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="newline">
        <xsl:param name="context" as="node()" select="."/>
        <xsl:param name="indent" as="xs:integer" select="0"/>
        <xsl:text>
</xsl:text>
        <xsl:for-each select="1 to (count($context/ancestor::*) + 1 + $indent)">
            <xsl:text>    </xsl:text>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="section" name="section">
        <xsl:variable name="document-lang" select="string((ancestor::html/(@lang, @xml:lang))[last()])" as="xs:string"/>
        <xsl:variable name="ancestor-lang" select="string((ancestor::*/(@lang, @xml:lang))[last()])" as="xs:string"/>
        <xsl:variable name="section-lang" select="string((@lang, @xml:lang)[last()])" as="xs:string"/>
        
        <xsl:choose>
            <xsl:when test="f:should-insert-break-point(.)">
                <xsl:if test="not(self::section intersect ancestor::body/section[1])">
                    <div class="html-break-point"/>
                </xsl:if>
                <xsl:call-template name="newline">
                    <xsl:with-param name="indent" select="-1"/>
                </xsl:call-template>
                <div>
                    <xsl:call-template name="apply-global-attributes"/>
                    <xsl:if test="$section-lang = '' and $ancestor-lang != $document-lang">
                        <xsl:attribute name="lang" select="$ancestor-lang" exclude-result-prefixes="#all"/>
                        <xsl:attribute name="xml:lang" select="$ancestor-lang" exclude-result-prefixes="#all"/>
                    </xsl:if>
                    <xsl:attribute name="class" select="string-join((@class, 'section-start'), ' ')"></xsl:attribute>
                </div>
                <xsl:call-template name="unwrap-nodes">
                    <xsl:with-param name="context" select="."/>
                    <xsl:with-param name="nodes" select="node()"/>
                </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="exists(descendant::section[f:should-insert-break-point(.)])">
                <div>
                    <xsl:call-template name="apply-global-attributes"/>
                    <xsl:if test="$section-lang = '' and $ancestor-lang != ''">
                        <xsl:attribute name="lang" select="$ancestor-lang" exclude-result-prefixes="#all"/>
                        <xsl:attribute name="xml:lang" select="$ancestor-lang" exclude-result-prefixes="#all"/>
                    </xsl:if>
                    <xsl:attribute name="class" select="string-join((@class, 'section-start'), ' ')"></xsl:attribute>
                </div>
                <xsl:call-template name="unwrap-nodes">
                    <xsl:with-param name="context" select="."/>
                    <xsl:with-param name="nodes" select="node()"/>
                </xsl:call-template>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@*"/>
                    <xsl:apply-templates select="node()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="unwrap-nodes">
        <xsl:param name="context" as="element()"/>
        <xsl:param name="nodes" as="node()*"/>
        
        <xsl:variable name="document-lang" select="string(($context/ancestor::html/(@lang, @xml:lang))[last()])" as="xs:string"/>
        <xsl:variable name="ancestor-lang" select="string(($context/ancestor-or-self::*/(@lang, @xml:lang))[last()])" as="xs:string"/>
        
        <xsl:for-each select="$nodes">
            <xsl:choose>
                <xsl:when test="$ancestor-lang = ''">
                    <!-- no language override found, nothing to do (shouldn't happen, there will at the very least be a lang at the html element) -->
                    <xsl:apply-templates select="."/>
                </xsl:when>
                
                <xsl:when test="self::section">
                    <!-- section elements are handled in its own template -->
                    <xsl:apply-templates select="."/>
                </xsl:when>
                
                <xsl:when test="not(self::*)">
                    <!-- nothing to do about non-element nodes (i.e. whitespace and comment nodes) -->
                    <xsl:apply-templates select="."/>
                </xsl:when>
                
                <xsl:otherwise>
                    <xsl:copy exclude-result-prefixes="#all">
                        <xsl:apply-templates select="@*"/>
                        <xsl:variable name="element-lang" select="string((@lang, @xml:lang)[last()])" as="xs:string"/>
                        <xsl:if test="$element-lang = '' and $ancestor-lang != $document-lang">
                            <xsl:attribute name="xml:lang" select="$ancestor-lang" exclude-result-prefixes="#all"/>
                            <xsl:attribute name="lang" select="$ancestor-lang" exclude-result-prefixes="#all"/>
                        </xsl:if>
                        <xsl:apply-templates select="node()"/>
                    </xsl:copy>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:function name="f:should-insert-break-point" as="xs:boolean">
        <xsl:param name="section" as="element()"/>
        
        <xsl:sequence select="f:types($section) = $breakBefore
                                or f:matter($section) = 'bodymatter' and f:types($section) = $breakBeforeInBodymatter
                                or not($section/ancestor::section)"/>
    </xsl:function>
    
    <xsl:function name="f:matter" as="xs:string">
        <xsl:param name="context" as="element()"/>
        <xsl:variable name="matter" select="(($context/ancestor-or-self::*/f:types(.))[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')])[last()]" as="xs:string?"/>
        <xsl:variable name="matter" select="if ($matter) then $matter else 'bodymatter'" as="xs:string"/>
        <xsl:value-of select="$matter"/>
    </xsl:function>
    
    <xsl:template name="apply-global-attributes">
        <xsl:param name="except" select="()" as="xs:string*"/>
        
        <!-- https://html.spec.whatwg.org/multipage/dom.html#global-attributes -->
        <xsl:apply-templates select="(
            @accesskey |
            @autocapitalize |
            @autofocus |
            @contenteditable |
            @dir |
            @draggable |
            @enterkeyhint |
            @hidden |
            @inputmode |
            @is |
            @itemid |
            @itemprop |
            @itemref |
            @itemscope |
            @itemtype |
            @lang |
            @nonce |
            @spellcheck |
            @style |
            @tabindex |
            @title |
            @translate |
            @slot |
            @class |
            @id
        )[not(name() = $except)]"/>
        
        <!-- include foreign namespaces (includes xml:lang, xml:space, epub:type, etc.) -->
        <xsl:apply-templates select="@*[contains(name(), ':') and not(name() = $except)]"/>
    </xsl:template>
    
    <xsl:function name="f:types">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:classes">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@class, '\s+')"/>
    </xsl:function>
    
</xsl:stylesheet>
