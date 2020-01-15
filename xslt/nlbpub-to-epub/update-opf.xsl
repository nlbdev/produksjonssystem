<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xmlns="http://www.idpf.org/2007/opf"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:param name="spine-hrefs" as="xs:string"/>
    
    <!-- set indent=no, and do the indentation manually, to make the output extra pretty -->
    <xsl:output indent="no" method="xml" exclude-result-prefixes="#all"/>
    
    <xsl:template match="@* | node()" exclude-result-prefixes="#all" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="package">
        <xsl:variable name="spine-items-and-itemrefs" as="element()+">
            <xsl:call-template name="create-spine-items-and-itemrefs"/>
        </xsl:variable>
        
        <xsl:variable name="manifest" as="element()">
            <xsl:call-template name="create-manifest">
                <xsl:with-param name="spine-items-and-itemrefs" select="$spine-items-and-itemrefs"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="spine" as="element()">
            <xsl:call-template name="create-spine">
                <xsl:with-param name="spine-items-and-itemrefs" select="$spine-items-and-itemrefs"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="metadata" as="element()">
            <xsl:call-template name="create-metadata">
                <xsl:with-param name="manifest" select="$manifest"/>
                <xsl:with-param name="spine" select="$spine"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="0"/></xsl:call-template>
        <package>
            <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
            
            <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="1"/></xsl:call-template>
            <xsl:copy-of select="$metadata" exclude-result-prefixes="#all"/>
            
            <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="1"/></xsl:call-template>
            <xsl:copy-of select="$manifest" exclude-result-prefixes="#all"/>
            
            <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="1"/></xsl:call-template>
            <xsl:copy-of select="$spine" exclude-result-prefixes="#all"/>
            
            <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="0"/></xsl:call-template>
        </package>
        <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="0"/></xsl:call-template>
    </xsl:template>
    
    <xsl:template name="create-spine-items-and-itemrefs" as="element()+">
        <xsl:variable name="package" select="." as="element()"/>

        <xsl:variable name="spineHrefs" select="tokenize($spine-hrefs, ',')" as="xs:string+"/>
        <xsl:variable name="base-uri" select="replace(base-uri(), '[^/]+$', '')" as="xs:string"/>
        
        <xsl:variable name="content" select="for $href in ($spineHrefs) return document(string(resolve-uri($href, $base-uri)))/*" as="element()+"/>
        <xsl:variable name="matters" select="f:matters($content)" as="xs:string+"/>
        <xsl:variable name="types" select="f:types($content)" as="xs:string+"/>
        
        <xsl:for-each select="$spineHrefs">
            <xsl:variable name="position" select="position()" as="xs:integer"/>
            <xsl:variable name="href" select="string(resolve-uri(., $base-uri))" as="xs:string"/>
            <xsl:variable name="content" select="document($href)/*" as="element()"/>
            
            <xsl:variable name="matter" select="$matters[position() = $position]" as="xs:string"/>
            <xsl:variable name="type" select="$types[position() = $position]" as="xs:string"/>
            <xsl:variable name="linear" select="f:linear($matter, $type)" as="xs:boolean"/>
            
            <xsl:variable name="content" select="document($href)/*"/>
            <xsl:variable name="properties" as="xs:string*">
                <xsl:if test="$content//*/local-name() = 'math'">
                    <xsl:sequence select="'mathml'"/>
                </xsl:if>
                
                <xsl:if test="$content//*/local-name() = 'script'">
                    <xsl:sequence select="'scripted'"/>
                </xsl:if>
                
                <xsl:if test="$content//*/local-name() = 'svg'">
                    <xsl:sequence select="'svg'"/>
                </xsl:if>
            </xsl:variable>
            
            <!-- create element in a variable, so that we can use it as context for generate-id(…) -->
            <xsl:variable name="item" as="element()">
                <item media-type="application/xhtml+xml" href="{.}">
                    <xsl:if test="count($properties) gt 0">
                        <xsl:attribute name="properties" select="string-join($properties, ' ')"/>
                    </xsl:if>
                    
                    <!--<xsl:attribute name="epub:type" select="concat($matter, ' ', $type)"/>-->  <!-- uncomment for debugging -->
                </item>
            </xsl:variable>
            <xsl:variable name="item-id" select="if (exists($package//*[contains(@id, 'spine_item_')])) then generate-id($item) else concat('spine_item_', position())"/>
            
            <xsl:variable name="itemref" as="element()">
                <itemref idref="{$item-id}">
                    <xsl:if test="not($linear)">
                        <xsl:attribute name="linear" select="'no'"/>
                    </xsl:if>
                </itemref>
            </xsl:variable>
            <xsl:variable name="itemref-id" select="if (exists($package//*[contains(@id, 'spine_itemref_')])) then generate-id($itemref) else concat('spine_itemref_', position())"/>
            
            <xsl:for-each select="$item">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    <xsl:attribute name="id" select="$item-id"/>
                </xsl:copy>
            </xsl:for-each>
            
            <xsl:for-each select="$itemref">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    <xsl:attribute name="id" select="$itemref-id"/>
                </xsl:copy>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="create-manifest" as="element()">
        <xsl:param name="spine-items-and-itemrefs" as="element()+"/>
        
        <manifest>
            <xsl:copy-of select="manifest/@*" exclude-result-prefixes="#all"/>
            
            <xsl:for-each select="manifest/item">
                <xsl:if test="tokenize(@properties, '\s+') = 'nav' or not(../../spine/itemref/@idref = @id)">
                    <xsl:call-template name="newline-indent"/>
                    <xsl:element name="{name()}">
                        <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    </xsl:element>
                </xsl:if>
            </xsl:for-each>
            
            <xsl:for-each select="$spine-items-and-itemrefs[self::item]">
                <xsl:call-template name="newline-indent"/>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:for-each>
        </manifest>
    </xsl:template>
    
    <xsl:template name="create-spine" as="element()">
        <xsl:param name="spine-items-and-itemrefs" as="element()+"/>
        <spine>
            <xsl:for-each select="$spine-items-and-itemrefs[self::itemref]">
                <xsl:call-template name="newline-indent"/>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:for-each>
            
            <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="1"/></xsl:call-template>
        </spine>
    </xsl:template>
    
    <xsl:template name="create-metadata" as="element()">
        <xsl:param name="manifest" as="element()"/>
        <xsl:param name="spine" as="element()"/>
        <xsl:copy-of select="metadata" exclude-result-prefixes="#all"/>
    </xsl:template>
    
    <xsl:template name="newline-indent">
        <xsl:param name="indent" select="2" as="xs:integer"/>  <!-- use 2 indents as default, as that's what we commmonly want in a OPF -->
        
        <!-- newline -->
        <xsl:text>
</xsl:text>
        
        <!-- indents -->
        <xsl:for-each select="1 to $indent">
            <xsl:text>    </xsl:text>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:function name="f:matters" as="xs:string+">
        <xsl:param name="contents" as="element()+"/>
        
        <xsl:variable name="matters" as="xs:string+">
            <xsl:for-each select="$contents">
                <xsl:variable name="from-section-start" select="(html:body/html:*[tokenize(@class, '\s+') = 'section-start'])[1]" as="element()?"/>
                <xsl:variable name="from-section-start" select="$from-section-start/tokenize(@epub:type, '\s+')[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')]" as="xs:string*"/>
                
                <xsl:variable name="from-filename" select="if (matches(base-uri(), '^.*/[^-]+-\d+-[a-z-]+.xhtml$')) then replace(base-uri(), '^.*/[^-]+-\d+-([a-z-]+).xhtml$', '$1') else ()" as="xs:string?"/>
                <xsl:variable name="from-filename" select="if ($from-filename = ('cover', 'frontmatter', 'bodymatter', 'backmatter')) then $from-filename else ()" as="xs:string?"/>
                
                <xsl:choose>
                    <xsl:when test="count($from-section-start) gt 0">
                        <xsl:value-of select="$from-section-start[1]"/>
                    </xsl:when>
                    <xsl:when test="$from-filename">
                        <xsl:value-of select="$from-filename"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="'unknown'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:for-each select="$matters">
            <xsl:variable name="position" select="position()" as="xs:integer"/>
            
            <xsl:choose>
                <xsl:when test=". != 'unknown'">
                    <xsl:value-of select="."/>
                </xsl:when>
                <xsl:when test="$matters[position() lt $position] = 'backmatter'">
                    <xsl:value-of select="'backmatter'"/>
                </xsl:when>
                <xsl:when test="$matters[position() lt $position] = 'bodymatter'">
                    <xsl:value-of select="'bodymatter'"/>
                </xsl:when>
                <xsl:when test="$matters[position() lt $position] = 'frontmatter'">
                    <xsl:value-of select="'frontmatter'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'cover'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>
    
    <xsl:function name="f:types" as="xs:string+">
        <xsl:param name="contents" as="element()+"/>
        
        <xsl:for-each select="$contents">
            <xsl:variable name="from-section-start" select="(html:body/html:*[tokenize(@class, '\s+') = 'section-start'])[1]" as="element()?"/>
            <xsl:variable name="from-section-start" select="$from-section-start/tokenize(@epub:type, '\s+')[not(. = ('cover', 'frontmatter', 'bodymatter', 'backmatter'))]" as="xs:string*"/>
            
            <xsl:variable name="from-filename" select="if (matches(base-uri(), '^.*/[^-]+-\d+-[a-z-]+.xhtml$')) then replace(base-uri(), '^.*/[^-]+-\d+-([a-z-]+).xhtml$', '$1') else ()" as="xs:string?"/>
            <xsl:variable name="from-filename" select="if (not($from-filename = ('cover', 'frontmatter', 'bodymatter', 'backmatter'))) then $from-filename else ()" as="xs:string?"/>
            
            <xsl:choose>
                <xsl:when test="count($from-section-start) gt 0">
                    <xsl:value-of select="$from-section-start[1]"/>
                </xsl:when>
                <xsl:when test="$from-filename">
                    <xsl:value-of select="$from-filename"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'chapter'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>
    
    <xsl:function name="f:linear" as="xs:boolean">
        <xsl:param name="matter" as="xs:string"/>
        <xsl:param name="type" as="xs:string"/>
        
        <xsl:choose>
            <xsl:when test="$matter = 'cover'">
                <xsl:sequence select="false()"/>
            </xsl:when>
            <xsl:when test="$type = ('appendix', 'colophon', 'credits', 'keywords',
                                     'index', 'glossary', 'bibliography',
                                     'case-study', 
                                     'footnotes', 'endnotes', 'rearnotes')">
                <xsl:sequence select="false()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="true()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>
