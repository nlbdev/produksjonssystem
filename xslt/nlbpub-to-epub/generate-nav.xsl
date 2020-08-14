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
    
    <xsl:template match="/*">
        <xsl:variable name="opf" select="/*" as="element()"/>
        
        <xsl:variable name="nav-href" select="$opf/opf:manifest/opf:item[tokenize(@properties, '\s+') = 'nav']/resolve-uri(@href, base-uri(.))" as="xs:anyURI"/>
        <xsl:variable name="nav" select="document($nav-href)/*" as="element()"/>
        
        <xsl:variable name="spine-hrefs" select="for $idref in ($opf/opf:spine/opf:itemref/@idref) return resolve-uri($opf/opf:manifest/opf:item[@id = $idref]/resolve-uri(@href, base-uri(.)))" as="xs:anyURI*"/>
        <xsl:variable name="spine" select="for $href in ($spine-hrefs) return document($href)/*" as="element()*"/>
        
        <xsl:call-template name="main">
            <xsl:with-param name="opf" select="$opf"/>
            <xsl:with-param name="nav" select="$nav"/>
            <xsl:with-param name="spine" select="$spine"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="main">
        <xsl:param name="opf" as="element()"/>
        <xsl:param name="nav" as="element()"/>
        <xsl:param name="spine" as="element()*"/>
        
        <xsl:variable name="base-uri-strip-length" select="string-length(replace($nav/base-uri(), '[^/]+$', '')) + 1"/>
        
        <xsl:for-each select="$nav">
            <xsl:copy exclude-result-prefixes="#all">
                <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                <xsl:copy-of select="body/preceding-sibling::node()"/> <!-- head element as well as any surrounding whitespace and comments -->
                <xsl:for-each select="body">
                    <xsl:copy exclude-result-prefixes="#all">
                        
                        <xsl:call-template name="generate-landmarks">
                            <xsl:with-param name="spine" select="$spine"/>
                            <xsl:with-param name="base-uri-strip-length" select="$base-uri-strip-length" tunnel="yes"/>
                        </xsl:call-template>
                        
                        <xsl:call-template name="generate-toc">
                            <xsl:with-param name="spine" select="$spine"/>
                            <xsl:with-param name="base-uri-strip-length" select="$base-uri-strip-length" tunnel="yes"/>
                        </xsl:call-template>
                        
                        <xsl:call-template name="generate-page-list">
                            <xsl:with-param name="spine" select="$spine"/>
                            <xsl:with-param name="base-uri-strip-length" select="$base-uri-strip-length" tunnel="yes"/>
                        </xsl:call-template>
                        
                    </xsl:copy>
                </xsl:for-each>
                <xsl:copy-of select="body/following-sibling::node()"/> <!-- any trailing whitespace and comments -->
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="generate-landmarks">
        <xsl:param name="spine" as="element()*"/>
        <xsl:param name="base-uri-strip-length" as="xs:integer" tunnel="yes"/>
        
        <xsl:variable name="headings" select="$spine//(h1 | h2 | h3 | h4 | h5 | h6)" as="element()+"/>
        
        <nav epub:type="landmarks" hidden="">
            <ol>
                <xsl:variable name="start-of-book" select="($headings[f:matter(.) = 'bodymatter'])[1]" as="element()"/>
                <xsl:variable name="language" select="($start-of-book/ancestor-or-self::*/@xml:lang)[last()]" as="xs:string"/>
                
                <xsl:variable name="text" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="$language = ('nb', 'nn', 'no')">
                            <xsl:text>Starten av boka</xsl:text>
                        </xsl:when>
                        <xsl:when test="$language = 'en'">
                            <xsl:text>Start of book</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Start</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <li><a href="{substring(base-uri($start-of-book), $base-uri-strip-length)}#{$start-of-book/@id}" epub:type="bodymatter"><xsl:value-of select="$text"/></a></li>
            </ol>
        </nav>
    </xsl:template>
    
    <xsl:template name="generate-toc">
        <xsl:param name="spine" as="element()*"/>
        
        <nav epub:type="toc">
            <ol>
                <xsl:call-template name="generate-toc-level">
                    <xsl:with-param name="level" select="1"/>
                    <xsl:with-param name="headings" select="$spine//(h1 | h2 | h3 | h4 | h5 | h6)"/>
                </xsl:call-template>
            </ol>
        </nav>
        
        <!--text(), @title, @alt-->
        
        <!-- TODO -->
    </xsl:template>
    
    <xsl:template name="generate-toc-level">
        <xsl:param name="level" as="xs:integer"/>
        <xsl:param name="headings" as="element()+"/>
        <xsl:param name="base-uri-strip-length" as="xs:integer" tunnel="yes"/>
        
        <xsl:for-each-group select="$headings" group-starting-with="*[f:heading-level(.) = $level]">
            <li>
                <xsl:variable name="heading" select="current-group()[1]"/>

                <!--
                    Handle hidden headlines (headlines that are only visible in the navigation document):
                    
                    <div id="…" class="hidden-headline-anchor"></div>
                    <h1 class="hidden-headline">…</h1>
                    
                    .hidden-headline { display: none; }
                -->
                <xsl:variable name="hidden-headline-anchor" select="($heading/preceding-sibling::div[1] intersect $heading/preceding-sibling::*[1])[tokenize(@class, '\s+') = 'hidden-headline-anchor']"/>
                <xsl:variable name="heading-id" select="(if ($heading/tokenize(@class, '\s+') = 'hidden-headline') then $hidden-headline-anchor/@id else (), $heading/@id)[1]"/>
                
                <xsl:variable name="href" select="substring(base-uri($heading), $base-uri-strip-length)"/>
                <a href="{$href}#{$heading-id}"><xsl:value-of select="normalize-space(string-join($heading//text(),''))"/></a>
                <xsl:if test="current-group()[position() gt 1]">
                    <ol>
                        <xsl:call-template name="generate-toc-level">
                            <xsl:with-param name="level" select="$level + 1"/>
                            <xsl:with-param name="headings" select="current-group()[position() gt 1]"/>
                        </xsl:call-template>
                    </ol>
                </xsl:if>
            </li>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:function name="f:heading-level">
        <xsl:param name="heading" as="element()"/>
        
        <xsl:variable name="section-ancestors" select="$heading/ancestor::section" as="element()*"/>
        
        <xsl:choose>
            <xsl:when test="not($section-ancestors)">
                <xsl:value-of select="xs:integer(concat('0', replace($heading/local-name(), '[^\d]', '')))"/>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:variable name="preceding-top-level-headline" select="(
                    $section-ancestors[1]/(preceding::* except preceding::section/(ancestor::* | self::* | descendant::*))
                    [self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6]
                )[last()]" as="element()?"/>
                
                <xsl:variable name="top-level" select="if ($preceding-top-level-headline) then xs:integer(concat('0', replace($preceding-top-level-headline/local-name(), '[^\d]', ''))) else 0"/>
                <xsl:value-of select="$top-level + count($section-ancestors)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:template name="generate-page-list">
        <xsl:param name="spine" as="element()*"/>
        <xsl:param name="base-uri-strip-length" as="xs:integer" tunnel="yes"/>
        
        <xsl:variable name="pagebreaks" select="$spine//*[tokenize(@epub:type, '\s+') = 'pagebreak' and exists(@id)]"/>
        
        <xsl:if test="count($pagebreaks) gt 0">
            <nav epub:type="page-list" hidden="">
                <ol>
                    <xsl:for-each select="$pagebreaks">
                        <xsl:variable name="page" select="string-join(.//text()[normalize-space()], '')" as="xs:string"/>
                        <xsl:variable name="page" select="if ($page = '') then @title else $page" as="xs:string"/>
                        <xsl:variable name="page" select="if ($page = '') then '?' else $page" as="xs:string"/>
                        
                        <li><a href="{substring(base-uri(.), $base-uri-strip-length)}#{@id}"><xsl:value-of select="$page"/></a></li>
                    </xsl:for-each>
                </ol>
            </nav>
        </xsl:if>
    </xsl:template>
    
    <xsl:function name="f:matter" as="xs:string">
        <xsl:param name="context" as="node()"/>
        
        <xsl:variable name="types" as="xs:string*">
            <xsl:for-each select="$context/ancestor-or-self::*">
                <xsl:sequence select="(preceding-sibling::*[tokenize(@class, '\s+') = 'section-start'])[1]/tokenize(@epub:type, '\s+')"/>
                <xsl:sequence select="tokenize(@epub:type, '\s+')"/>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="matter" select="$types[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')]" as="xs:string*"/>
        <xsl:value-of select="if (count($matter)) then $matter[last()] else 'bodymatter'"/>
    </xsl:function>
    
</xsl:stylesheet>
