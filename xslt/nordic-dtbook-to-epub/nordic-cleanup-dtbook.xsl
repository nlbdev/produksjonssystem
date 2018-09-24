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
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>

            <!-- xpath expressions based on expressions in dtbook-to-epub3.xsl in nordic migrator -->
            <xsl:variable name="implicit-footnotes-or-rearnotes" select="if (dtbook:note[not(//dtbook:table//dtbook:noteref/substring-after(@idref,'#')=@id)]) then if (ancestor::dtbook:frontmatter) then false() else true() else false()"/>
            <xsl:variable name="implicit-toc" select="if (dtbook:list[tokenize(@class,'\s+')='toc']) then true() else false()"/>
            <xsl:if test="not($implicit-footnotes-or-rearnotes or $implicit-toc) and (parent::*/tokenize(@class,'\s+') = 'part' or self::level1 or parent::book) and string(@class) = ''">
                <xsl:attribute name="class" select="'chapter'"/>
            </xsl:if>
            
            <xsl:if test="dtbook:list/tokenize(@class,'\s+') = 'index'">
                <xsl:attribute name="class" select="string-join((@class,'index'),' ')"/>
            </xsl:if>
            
            <!-- text nodes and pagenum can be before headlines -->
            <xsl:variable name="before-headline" select="node() intersect (*[not(local-name()='pagenum')])[1]/preceding-sibling::node()" as="node()*"/>
            <xsl:apply-templates select="$before-headline"/>
            
            <!-- conditionally insert headline -->
            <xsl:if test="tokenize(@class,'\s+') = 'colophon' and not(exists(dtbook:*[matches(local-name(),'h[d\d]')]))">
                <xsl:element name="h{f:level(.)}" exclude-result-prefixes="#all">
                    <xsl:text>Kolofon</xsl:text>
                </xsl:element>
            </xsl:if>
            
            <!-- remaining elements and other nodes -->
            <xsl:apply-templates select="node() except $before-headline"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:p[../dtbook:lic]">
        <lic>
            <xsl:apply-templates select="@* | node()"/>
        </lic>
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
