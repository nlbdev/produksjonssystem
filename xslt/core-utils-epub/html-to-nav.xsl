<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:functx="http://www.functx.com"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output method="xhtml" indent="yes" include-content-type="no"/>
    
    <xsl:template match="/html:html">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@lang | @xml:lang" exclude-result-prefixes="#all"/>
            <xsl:apply-templates select="*">
                <xsl:with-param name="content-filename" select="tokenize(base-uri(.),'/')[last()]" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html:head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="html:meta[@charset]" exclude-result-prefixes="#all"/>
            <xsl:copy-of select="html:title" exclude-result-prefixes="#all"/>
            <xsl:copy-of select="html:meta[@name='dc:identifier']" exclude-result-prefixes="#all"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html:body">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:call-template name="toc"/>
            <xsl:call-template name="page-list"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="toc">
        <nav epub:type="toc">
            <h1>Innholdsfortegnelse</h1>
            <ol>
                <xsl:apply-templates select="." mode="toc"/>
            </ol>
        </nav>
    </xsl:template>
    
    <xsl:template match="*" mode="toc">
        <xsl:choose>
            <xsl:when test="self::html:section">
                <li>
                    <xsl:call-template name="headline"/>
                    <xsl:if test="descendant::html:section">
                        <ol>
                            <xsl:apply-templates select="*" mode="#current"/>
                        </ol>
                    </xsl:if>
                </li>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="*" mode="#current"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="page-list">
        <xsl:variable name="pagebreaks" select=".//*[tokenize(@epub:type,'\s+') = 'pagebreak']"/>
        <xsl:if test="count($pagebreaks) gt 0">
            <nav epub:type="page-list" hidden="">
                <h1>Liste over sider</h1>
                <ol>
                    <xsl:for-each select="$pagebreaks">
                        <li>
                            <xsl:call-template name="pagebreak"/>
                        </li>
                    </xsl:for-each>
                </ol>
            </nav>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="headline">
        <xsl:param name="content-filename" as="xs:string" tunnel="yes"/>
        <xsl:variable name="headline-element" select="(
                                                        (descendant::* except descendant::html:section/descendant-or-self::*)
                                                        [matches(local-name(),'^h\d$')]
                                                      )[1]" as="element()?"/>
        <xsl:variable name="headline-id" select="($headline-element/@id, @id)[1]" as="xs:string?"/>
        
        <xsl:variable name="epub-types" select="for $type in (tokenize(@epub:type,'\s+')) return if ($type = ('frontmatter','bodymatter','backmatter')) then () else tokenize($type,':')[last()]"/>
        <xsl:variable name="epub-types" select="if (count($epub-types) = 0) then for $type in (tokenize(@epub:type,'\s+')) return tokenize($type,':')[last()] else $epub-types"/>
        
        <xsl:variable name="headline" select="$headline-element/normalize-space(string-join(.//text(),''))" as="xs:string?"/>
        <xsl:variable name="headline" select="if ($headline) then $headline else
                                              if (count($epub-types)) then string-join(for $type in ($epub-types) return functx:capitalize-first($type), ' ') else
                                              functx:capitalize-first(local-name())"/>
        <xsl:if test="not($headline-id)">
            <xsl:message select="concat('Could not find id for headline ''',$headline,''' at ''',string-join(ancestor-or-self::*/concat('*[',count(preceding-sibling::*),'][self::',name(),']'),'/'),'''')"/>
        </xsl:if>
        <a href="{$content-filename}#{$headline-id}">
            <xsl:value-of select="$headline"/>
        </a>
    </xsl:template>
    
    <xsl:template name="pagebreak">
        <xsl:param name="content-filename" as="xs:string" tunnel="yes"/>
        
        <xsl:variable name="page" select="if (string(@title)) then @title else text()" as="xs:string?"/>
        
        <xsl:if test="not(string(@id))">
            <xsl:message select="concat('Could not find id for pagebreak ''',$page,''' at ''',string-join(ancestor-or-self::*/concat('*[',count(preceding-sibling::*),'][self::',name(),']'),'/'),'''')"/>
        </xsl:if>
        <xsl:if test="not($page)">
            <xsl:message select="concat('Could not find page number for pagebreak at ''',string-join(ancestor-or-self::*/concat('*[',count(preceding-sibling::*),'][self::',name(),']'),'/'),'''')"/>
        </xsl:if>
        
        <a href="{$content-filename}#{@id}">
            <xsl:value-of select="$page"/>
        </a>
    </xsl:template>
    
    <xsl:function name="functx:capitalize-first" as="xs:string?">
        <!-- from http://www.xsltfunctions.com/xsl/functx_capitalize-first.html -->
        
        <xsl:param name="arg" as="xs:string?"/>
        
        <xsl:sequence select="concat(upper-case(substring($arg,1,1)), substring($arg,2))"/>
    </xsl:function>
    
</xsl:stylesheet>