<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
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
    
    <xsl:template match="head">
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
    
    <xsl:template match="meta[@name=('dc:Identifier','dtb:uid')]">
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
    
    <xsl:template match="meta[@name='track:Guidelines' and not(@content=('2011-1','2011-2','2015-1'))]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@* except @content" exclude-result-prefixes="#all"/>
            <xsl:attribute name="content" select="'2015-1'"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="meta[@name='dt:version']"/>
    
    <xsl:template match="hd">
        <xsl:variable name="ancestor-levels" select="ancestor::*/*[matches(local-name(),'(level\d?|sidebar)')]"/>
        <xsl:variable name="parent-level" select="if (count($ancestor-levels)) then max(for $levelx in $ancestor-levels return xs:integer(
                                                                                            if (not(matches($levelx/local-name(), 'level\d'))) then count($levelx/ancestor-or-self::*[matches(local-name(),'(level\d?|sidebar)')])
                                                                                            else replace($levelx/local-name(), '[^\d]', '')
                                                                                        )) else 1" as="xs:integer"/>
        <xsl:element name="h{f:level(.)}" namespace="http://www.daisy.org/z3986/2005/dtbook/">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="book">
        <xsl:next-match>
            <xsl:with-param name="toc-count" select="count(*/level1[f:is-toc(.)])" as="xs:integer" tunnel="yes"/>
        </xsl:next-match>
    </xsl:template>
    
    <xsl:template match="*[matches(local-name(),'(level\d?|sidebar)')]">
        <xsl:param name="include-always" select="false()" tunnel="yes" as="xs:boolean"/>
        <xsl:param name="toc-count" select="0" tunnel="yes" as="xs:integer"/>
        
        <xsl:variable name="level" select="f:level(.)"/>
        
        <xsl:if test="not(f:move-to-frontmatter(., $toc-count)) or $include-always">
            <xsl:copy exclude-result-prefixes="#all">
                <xsl:apply-templates select="@* except @class"/>
                
                <xsl:variable name="classes" select="tokenize(@class,'\s+')" as="xs:string*"/>
    
                <!-- xpath expressions based on expressions in dtbook-to-epub3.xsl in nordic migrator -->
                <xsl:variable name="classes" select="($classes, if (f:is-main-toc(., $toc-count)) then 'toc' else if (f:is-toc(.)) then 'toc-brief' else ())"/>
                <xsl:variable name="classes" select="if ($classes[.='toc-brief']) then $classes[not(.='toc')] else $classes"/>  <!-- remove toc class if there's a toc-brief class -->
                
                <xsl:variable name="implicit-footnotes-or-rearnotes" select="if (note[not(//table//noteref/substring-after(@idref,'#')=@id)]) then if (ancestor::frontmatter) then false() else true() else false()"/>
                <xsl:variable name="classes" select="($classes, if (not($implicit-footnotes-or-rearnotes or f:is-toc(.)) and (parent::*/tokenize(@class,'\s+') = 'part' or self::level1 or parent::book) and count($classes) = 0) then 'chapter' else ())" as="xs:string*"/>
                
                <xsl:variable name="classes" select="($classes, if (list/tokenize(@class,'\s+') = 'index') then 'index' else ())" as="xs:string*"/>
                
                <xsl:variable name="level" select="f:level(.)"/>
                <xsl:variable name="notes-on-same-level" select="f:notes-on-same-level(.)" as="xs:boolean"/>
                
                <xsl:if test="count($classes)">
                    <xsl:attribute name="class" select="string-join(distinct-values($classes), ' ')"/>
                </xsl:if>
                
                <!-- text nodes and pagenum can be before headlines -->
                <xsl:variable name="before-headline" select="if ($notes-on-same-level) then () else node() intersect (*[not(local-name()='pagenum')])[1]/preceding-sibling::node()" as="node()*"/>
                <xsl:apply-templates select="$before-headline">
                    <xsl:with-param name="toc-count" select="$toc-count" as="xs:integer" tunnel="yes"/>
                </xsl:apply-templates>
                
                <!-- conditionally insert headline -->
                <xsl:if test="tokenize(@class,'\s+') = 'colophon' and not(exists(*[matches(local-name(),'h[d\d]')]))">
                    <xsl:element name="h{$level}" exclude-result-prefixes="#all">
                        <xsl:text>Kolofon</xsl:text>
                    </xsl:element>
                </xsl:if>
                
                <!-- content before subchapters -->
                <xsl:variable name="child-chapters" select="*[matches(local-name(),'(level\d?|sidebar)')]/(self::* | following-sibling::*)"/>
                <xsl:variable name="content" select="if (exists($child-chapters)) then node() except $child-chapters[1]/(self::* | following-sibling::node()) else node()"/>
                <xsl:apply-templates select="$content except $before-headline">
                    <xsl:with-param name="toc-count" select="$toc-count" as="xs:integer" tunnel="yes"/>
                </xsl:apply-templates>
                
                <!-- pagenums in subchapters containing notes (but only note chapters without preceding sibling chapters that are not note chapters) -->
                <xsl:if test="not($notes-on-same-level)">
                    <xsl:variable name="child-chapters-with-notes" select="$child-chapters[f:notes-on-same-level(.)] except $child-chapters[not(f:notes-on-same-level(.))]/(self::* | following-sibling::*)"/>
                    <!--<xsl:if test="exists($child-chapters-with-notes//pagenum)">
                        <xsl:text>  </xsl:text>
                        <xsl:comment select="' moving pagenum(s) here from child chapters with notes '"/>
                    </xsl:if>-->
                    <xsl:copy-of select="$child-chapters-with-notes//pagenum"/>
                </xsl:if>
                
                <!-- subchapters -->
                <xsl:apply-templates select="$child-chapters">
                    <xsl:with-param name="toc-count" select="$toc-count" as="xs:integer" tunnel="yes"/>
                </xsl:apply-templates>
                
                <!-- pagenums in following chapters containing notes (but only note chapters without preceding sibling chapters that are not note chapters) -->
                <xsl:if test="not($notes-on-same-level)">
                    <xsl:variable name="following-chapters" select="following-sibling::*[matches(local-name(),'(level\d?|sidebar)')]"/>
                    <xsl:variable name="following-chapters-with-notes" select="$following-chapters[f:notes-on-same-level(.)] except $following-chapters[not(f:notes-on-same-level(.))]/(self::* | following-sibling::*)"/>
                    <!--<xsl:if test="exists($following-chapters-with-notes//pagenum)">
                        <xsl:text>  </xsl:text>
                        <xsl:comment select="' moving pagenum(s) here from following chapters with notes '"/>
                    </xsl:if>-->
                    <xsl:copy-of select="$following-chapters-with-notes//pagenum"/>
                </xsl:if>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    
    <!-- remove pagenums which has notes on the same level as itself (they will be moved to a preceding level in another template) -->
    <xsl:template match="pagenum[f:notes-on-same-level(.)]" priority="2"/>
    
    <xsl:function name="f:notes-on-same-level" as="xs:boolean">
        <xsl:param name="context" as="element()"/>
        <xsl:variable name="level" select="f:level($context)"/>
        <xsl:variable name="level-element" select="$context/ancestor-or-self::*[local-name() = ('level1', 'level2', 'level3', 'level4', 'level5', 'level6', 'level', 'sidebar') and f:level(.) = $level]"/>
        <xsl:variable name="notes-on-same-level" select="$level-element//note[f:level(.) = $level]"/>
        <xsl:value-of select="exists($notes-on-same-level)"/>
    </xsl:function>
    
    <xsl:template match="p[../lic]">
        <lic>
            <xsl:apply-templates select="@* | node()"/>
        </lic>
    </xsl:template>
    
    <xsl:template match="p[parent::sidebar]">
        <xsl:variable name="this" select="."/>
        
        <xsl:variable name="p" as="element()?">
            <xsl:next-match/>
        </xsl:variable>
        
        <xsl:variable name="following-adjacent-pagebreaks" select="following-sibling::pagenum intersect following-sibling::*[not(self::pagenum)][1]/preceding-sibling::* | (if (not(exists(following-sibling::* except following-sibling::pagenum))) then following-sibling::pagenum else ())" as="element()*"/>
        <xsl:variable name="preceding-adjacent-pagebreaks" select="preceding-sibling::pagenum intersect preceding-sibling::*[not(self::pagenum)][1]/following-sibling::* | (if (not(exists(preceding-sibling::* except preceding-sibling::pagenum))) then preceding-sibling::pagenum else ())" as="element()*"/>
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
    
    <xsl:template match="pagenum[parent::sidebar and (preceding-sibling::*[1], following-sibling::*[1])/local-name() = 'p']"/>
    <xsl:template match="pagenum[parent::list]"/>
    
    <xsl:template match="list[tokenize(@class,'\s+') = 'toc']">
        <xsl:param name="toc-count" select="0" tunnel="yes" as="xs:integer"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @class"/>
            
            <xsl:choose>
                <xsl:when test="exists(parent::*[f:is-main-toc(., $toc-count)])">
                    <xsl:apply-templates select="@class"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="filtered-classes" select="for $class in tokenize(@class,'\s+') return if ($class = 'toc') then () else $class"/>
                    <xsl:if test="count($filtered-classes) gt 0">
                        <xsl:attribute name="class" select="string-join($filtered-classes, ' ')"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="list[tokenize(@class,'\s+') = 'index']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @class"/>
            
            <xsl:if test="not(normalize-space(@class) = 'index')">
                <xsl:attribute name="class" select="string-join(tokenize(@class,'\s+')[not(.='index')],' ')"/>
            </xsl:if>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="list" priority="2">
        <xsl:variable name="level" select="f:level(.)" as="xs:integer"/>
        <xsl:variable name="is-note-level" select="exists(ancestor::*[matches(local-name(),'^(level\d|sidebar)') and exists(.//note[f:level(.) = $level])])" as="xs:boolean"/>
        
        <!-- pagenums at the beginning of the list should be moved out of the list -->
        <xsl:variable name="leading-pagenums" select="pagenum[not(preceding-sibling::li)]" as="element()*"/>
        <xsl:if test="not($is-note-level)">
           <xsl:copy-of select="$leading-pagenums" exclude-result-prefixes="#all"/>
        </xsl:if>
        
        <xsl:next-match/>
        
        <!-- pagenums at the end of the list should be moved out of the list -->
        <xsl:if test="not($is-note-level)">
            <xsl:apply-templates select="pagenum[not(following-sibling::li)] except $leading-pagenums"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="li">
        <xsl:variable name="level" select="f:level(.)" as="xs:integer"/>
        <xsl:variable name="is-note-level" select="exists(ancestor::*[matches(local-name(),'^(level\d|sidebar)') and exists(.//note[f:level(.) = $level])])" as="xs:boolean"/>
        
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            
            <!-- move preceding pagenums into the list item -->
            <xsl:if test="not($is-note-level)">
                <xsl:copy-of select="preceding-sibling::li[1]/following-sibling::pagenum intersect preceding-sibling::pagenum"/>
            </xsl:if>
            
            <xsl:apply-templates select="node()[not(normalize-space()='&gt;')]"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*" priority="3">
        <xsl:choose>
            <!-- based on xpath from mtm2015-1.sch in nordic migrator -->
            <xsl:when test="not(false() = (for $node in (descendant-or-self::node()) return (normalize-space($node)='' and not($node/self::img or $node/self::br or $node/self::meta or $node/self::link or $node/self::col or $node/self::th or $node/self::td or $node/self::dd or $node/self::pagenum[@page='special']))))"/>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="h1/text() | h2/text() | h3/text() | h4/text() | h5/text() | h6/text() | hd/text()">
        <xsl:value-of select="normalize-space()"/>
    </xsl:template>
    
    <xsl:template match="byline">
        <p>
            <xsl:apply-templates select="@* except @class"/>
            <xsl:attribute name="class" select="string-join((tokenize(@class,'\s+'), 'byline'),' ')"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>
    
    <xsl:template match="frontmatter">
        <xsl:param name="toc-count" select="0" as="xs:integer" tunnel="yes"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()">
                <xsl:with-param name="toc-count" select="$toc-count" as="xs:integer" tunnel="yes"/>
            </xsl:apply-templates>
            
            <xsl:if test="not(exists(level1))">
                <level1 class="titlepage">
                    <h1 class="title fulltitle"><xsl:value-of select="normalize-space(string-join(doctitle//text(),' '))"/></h1>
                    <xsl:for-each select="docauthor">
                        <p class="docauthor author"><xsl:value-of select="normalize-space(string-join(.//text(),' '))"/></p>
                    </xsl:for-each>
                </level1>
            </xsl:if>
            
            <xsl:apply-templates select="../bodymatter/level1[f:move-to-frontmatter(., $toc-count)]">
                <xsl:with-param name="include-always" select="true()" tunnel="yes"/>
                <xsl:with-param name="toc-count" select="$toc-count" as="xs:integer" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="img/@src">
        <xsl:attribute name="src" select="lower-case(.)"/>
    </xsl:template>
    
    <xsl:function name="f:move-to-frontmatter" as="xs:boolean">
        <xsl:param name="level" as="element()"/>
        <xsl:param name="toc-count" as="xs:integer"/>
        <xsl:value-of select="$level[parent::bodymatter] and not($level/preceding-sibling::level1) and f:is-toc($level) and $toc-count = 1"/>
    </xsl:function>
    
    <xsl:function name="f:is-main-toc" as="xs:boolean">
        <xsl:param name="level" as="element()"/>
        <xsl:param name="toc-count" as="xs:integer"/>
        <xsl:value-of select="f:is-toc($level) and $toc-count = 1 and ($level/parent::frontmatter or f:move-to-frontmatter($level, $toc-count))"/>
    </xsl:function>
    
    <xsl:function name="f:is-toc" as="xs:boolean">
        <xsl:param name="level" as="element()"/>
        <xsl:value-of select="exists($level/list[tokenize(@class,'\s+')='toc'])"/>
    </xsl:function>
    
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
