<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dtbook="http://www.daisy.org/z3986/2005/dtbook/"
                xmlns:f="#"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" include-content-type="no"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            
            <xsl:if test="not(*/@name='dtb:uid') and not(*/@name='dc:Identifier')">
                <xsl:variable name="identifier" select="replace(replace(base-uri(),'.*/',''),'\..*','')"/>
                <meta name="dtb:uid" content="{$identifier}"/>
                <meta name="dc:Identifier" content="{$identifier}"/>
            </xsl:if>
            
            <xsl:if test="not(*/@name = 'dc:Publisher')">
                <meta name="dc:Publisher" content="NLB"/>
            </xsl:if>
            
            <xsl:if test="not(*/@name = 'track:Guidelines')">
                <meta name="track:Guidelines" content="2015-1"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:meta[@name=('dc:Identifier','dtb:uid')]">
        <xsl:variable name="test" select="starts-with(@content, 'TEST')" as="xs:boolean"/>
        <xsl:variable name="identifier" select="replace(@content, '[^\d]', '')" as="xs:string"/>
        <xsl:variable name="content" select="concat(if ($test) then @content else '', $identifier)"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="content" select="$content"/>
        </xsl:copy>
        
        <xsl:if test="@name = 'dtb:uid' and not(../*/@name = 'dc:Identifier')">
            <meta name="dc:Identifier" content="{$content}"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="dtbook:meta[@name='track:Guidelines' and not(@content=('2011-1','2011-2','2015-1'))]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@* except @content" exclude-result-prefixes="#all"/>
            <xsl:attribute name="content" select="'2015-1'"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:meta[@name='dt:version']"/>
    
    <xsl:template match="dtbook:hd">
        <xsl:variable name="ancestor-levels" select="ancestor::*/dtbook:*[matches(local-name(),'(level\d?|sidebar)')]"/>
        <xsl:variable name="parent-level" select="if (count($ancestor-levels)) then max(for $levelx in $ancestor-levels return xs:integer(
                                                                                            if (not(matches($levelx/local-name(), 'level\d'))) then count($levelx/ancestor-or-self::dtbook:*[matches(local-name(),'(level\d?|sidebar)')])
                                                                                            else replace($levelx/local-name(), '[^\d]', '')
                                                                                        )) else 1" as="xs:integer"/>
        <xsl:element name="h{f:level(.)}" namespace="http://www.daisy.org/z3986/2005/dtbook/">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="dtbook:*[matches(local-name(),'(level\d?|sidebar)')]">
        <xsl:variable name="level" select="f:level(.)"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @class"/>
            
            <xsl:variable name="classes" select="tokenize(@class,'\s+')" as="xs:string*"/>

            <!-- xpath expressions based on expressions in dtbook-to-epub3.xsl in nordic migrator -->
            <xsl:variable name="one-of-multiple-tocs" select="exists(dtbook:list[tokenize(@class,'\s+')='toc']) and count(//dtbook:list[tokenize(@class,'\s+')='toc']) gt 1"/>
            <xsl:variable name="classes" select="($classes, if ($one-of-multiple-tocs) then 'toc-brief' else ())"/>
            
            <xsl:variable name="implicit-footnotes-or-rearnotes" select="if (dtbook:note[not(//dtbook:table//dtbook:noteref/substring-after(@idref,'#')=@id)]) then if (ancestor::dtbook:frontmatter) then false() else true() else false()"/>
            <xsl:variable name="implicit-toc" select="if (not($one-of-multiple-tocs) and exists(dtbook:list[tokenize(@class,'\s+')='toc'])) then true() else false()"/>
            <xsl:variable name="classes" select="($classes, if (not($implicit-footnotes-or-rearnotes or $implicit-toc or $one-of-multiple-tocs) and (parent::*/tokenize(@class,'\s+') = 'part' or self::level1 or parent::book) and count($classes) = 0) then 'chapter' else ())" as="xs:string*"/>
            
            <xsl:variable name="classes" select="($classes, if (dtbook:list/tokenize(@class,'\s+') = 'index') then 'index' else ())" as="xs:string*"/>
            
            <xsl:if test="count($classes)">
                <xsl:attribute name="class" select="string-join($classes, ' ')"/>
            </xsl:if>
            
            <!-- text nodes and pagenum can be before headlines -->
            <xsl:variable name="before-headline" select="node() intersect (*[not(local-name()='pagenum')])[1]/preceding-sibling::node()" as="node()*"/>
            <xsl:apply-templates select="$before-headline"/>
            
            <!-- conditionally insert headline -->
            <xsl:if test="tokenize(@class,'\s+') = 'colophon' and not(exists(dtbook:*[matches(local-name(),'h[d\d]')]))">
                <xsl:element name="h{$level}" exclude-result-prefixes="#all">
                    <xsl:text>Kolofon</xsl:text>
                </xsl:element>
            </xsl:if>
            
            <!-- remaining elements and other nodes -->
            <xsl:apply-templates select="node() except $before-headline"/>
            
            <xsl:if test="not(exists(.//note[f:level(.) = $level])) and exists(following-sibling::*[1]//note[f:level(.) = $level])">
                <xsl:for-each select="(following-sibling::* intersect following-sibling::*[not(exists(.//note[f:level(.) = $level]))][1]/preceding-sibling::*)//pagenum">
                    <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                </xsl:for-each>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:pagenum">
        <xsl:variable name="level" select="f:level(.)"/>
        <xsl:variable name="notes-on-same-level" select="ancestor::*[f:level(.) = $level]/descendant::*[self::note and f:level(.) = $level]" as="element()*"/>
        <xsl:if test="not(exists($notes-on-same-level))">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="dtbook:p[../dtbook:lic]">
        <lic>
            <xsl:apply-templates select="@* | node()"/>
        </lic>
    </xsl:template>
    
    <xsl:template match="dtbook:p[parent::dtbook:sidebar]">
        <xsl:variable name="this" select="."/>
        
        <xsl:variable name="p" as="element()?">
            <xsl:next-match/>
        </xsl:variable>
        
        <xsl:variable name="following-adjacent-pagebreaks" select="following-sibling::dtbook:pagenum intersect following-sibling::*[not(self::dtbook:pagenum)][1]/preceding-sibling::* | (if (not(exists(following-sibling::* except following-sibling::dtbook:pagenum))) then following-sibling::dtbook:pagenum else ())" as="element()*"/>
        <xsl:variable name="preceding-adjacent-pagebreaks" select="preceding-sibling::dtbook:pagenum intersect preceding-sibling::*[not(self::dtbook:pagenum)][1]/following-sibling::* | (if (not(exists(preceding-sibling::* except preceding-sibling::dtbook:pagenum))) then preceding-sibling::dtbook:pagenum else ())" as="element()*"/>
        <xsl:variable name="preceding-adjacent-pagebreaks" select="$preceding-adjacent-pagebreaks[not(preceding-sibling::*[1]/local-name() = 'p')]" as="element()*"/>
        
        <xsl:choose>
            <xsl:when test="exists($p)">
                <xsl:for-each select="$p">
                    <xsl:copy exclude-result-prefixes="#all">
                        <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                        <xsl:copy-of select="$preceding-adjacent-pagebreaks"/>
                        <xsl:copy-of select="node()" exclude-result-prefixes="#all"/>
                        <xsl:copy-of select="$following-adjacent-pagebreaks"/>
                    </xsl:copy>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="@id"/>
                    <xsl:apply-templates select="$preceding-adjacent-pagebreaks | $following-adjacent-pagebreaks"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="dtbook:pagenum[parent::dtbook:sidebar and (preceding-sibling::*[1], following-sibling::*[1])/local-name() = 'p']"/>
    
    <xsl:template match="dtbook:list[tokenize(@class,'\s+') = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @class"/>
            
            <xsl:variable name="multiple-tocs" select="count(//dtbook:list[tokenize(@class,'\s+')='toc']) gt 1"/>
            <xsl:choose>
                <xsl:when test="$multiple-tocs">
                    <xsl:if test="normalize-space(@class) != 'toc'">
                        <xsl:attribute name="class" select="tokenize(@class,'\s+')[not(.='toc')]"/>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="@class"/>
                </xsl:otherwise>
            </xsl:choose>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:list[tokenize(@class,'\s+') = 'index']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @class"/>
            
            <xsl:if test="not(normalize-space(@class) = 'index')">
                <xsl:attribute name="class" select="string-join(tokenize(@class,'\s+')[not(.='index')],' ')"/>
            </xsl:if>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:*" priority="2">
        <xsl:choose>
            <!-- based on xpath from mtm2015-1.sch in nordic migrator -->
            <xsl:when test="not(false() = (for $node in (descendant-or-self::node()) return (normalize-space($node)='' and not($node/self::dtbook:img or $node/self::dtbook:br or $node/self::dtbook:meta or $node/self::dtbook:link or $node/self::dtbook:col or $node/self::dtbook:th or $node/self::dtbook:td or $node/self::dtbook:dd or $node/self::dtbook:pagenum[@page='special']))))"/>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="dtbook:h1/text() | dtbook:h2/text() | dtbook:h3/text() | dtbook:h4/text() | dtbook:h5/text() | dtbook:h6/text() | dtbook:hd/text()">
        <xsl:value-of select="normalize-space()"/>
    </xsl:template>
    
    <xsl:template match="dtbook:byline">
        <p>
            <xsl:apply-templates select="@* except @class"/>
            <xsl:attribute name="class" select="string-join((tokenize(@class,'\s+'), 'byline'),' ')"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>
    
    <xsl:template match="dtbook:frontmatter">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            
            <xsl:if test="not(exists(dtbook:level1))">
                <level1 class="titlepage">
                    <h1 class="title fulltitle"><xsl:value-of select="normalize-space(string-join(dtbook:doctitle//text(),' '))"/></h1>
                    <xsl:for-each select="dtbook:docauthor">
                        <p class="docauthor author"><xsl:value-of select="normalize-space(string-join(.//text(),' '))"/></p>
                    </xsl:for-each>
                </level1>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="f:level" as="xs:integer">
        <xsl:param name="context" as="element()"/>
        <xsl:variable name="numbered-level" select="($context/ancestor-or-self::*[matches(local-name(),'level\d') or *[matches(local-name(),'h\d')]])[last()]" as="element()?"/>
        <xsl:variable name="numbered-level-number" select="if (not(exists($numbered-level))) then 0 else
                                                           if (matches($numbered-level/local-name(),'level\d')) then xs:integer(replace($numbered-level/local-name(),'[^\d]',''))
                                                           else xs:integer(replace(($numbered-level/*[matches(local-name(),'h\d')])[1]/local-name(),'[^\d]',''))" as="xs:integer"/>
        <xsl:variable name="unnumbered-levels" select="if (exists($numbered-level)) then $context/ancestor-or-self::* intersect $numbered-level/descendant::* else $context/ancestor-or-self::*" as="element()*"/>
        <xsl:variable name="unnumbered-levels" select="$unnumbered-levels[local-name() = ('level','sidebar','linegroup','poem','list')]" as="element()*"/>
        <xsl:variable name="level" select="$numbered-level-number + count($unnumbered-levels)" as="xs:integer"/>
        
        <xsl:value-of select="$level"/>
    </xsl:function>
    
</xsl:stylesheet>
