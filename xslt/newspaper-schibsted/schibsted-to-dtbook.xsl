<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:npdoc="http://www.infomaker.se/npdoc/2.1"
                xmlns:npx="http://www.infomaker.se/npexchange/3.5"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                xmlns:f="#"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    <!--<xsl:output indent="yes" doctype-public="-//NISO//DTD dtbook 2005-3//EN"/>-->
    
    <xsl:param name="identifier" as="xs:string"/>
    <xsl:param name="title" select="/*/npx:origin/npx:organization/text()" as="xs:string"/> <!-- optional but recommended -->
    <xsl:param name="date" select="replace(string(current-date()),'\+.*','')" as="xs:string"/> <!-- optional, YYYY-MM-DD -->
    
    <xsl:variable name="year" select="tokenize($date,'-')[1]"/>
    <xsl:variable name="month" select="tokenize($date,'-')[2]"/>
    <xsl:variable name="day" select="tokenize($date,'-')[3]"/>
    
    <xsl:variable name="month-name" select="if ($month = '01') then 'januar'
                                            else if ($month = '02') then 'februar'
                                            else if ($month = '03') then 'mars'
                                            else if ($month = '04') then 'april'
                                            else if ($month = '05') then 'mai'
                                            else if ($month = '06') then 'juni'
                                            else if ($month = '07') then 'juli'
                                            else if ($month = '08') then 'august'
                                            else if ($month = '09') then 'september'
                                            else if ($month = '10') then 'oktober'
                                            else if ($month = '11') then 'november'
                                            else if ($month = '12') then 'desember'
                                            else $month"/>
    <xsl:variable name="day-of-week" select="xs:integer((xs:date($date) - xs:date('1901-01-06')) div xs:dayTimeDuration('P1D')) mod 7"/>
    <xsl:variable name="day-of-week-name" select="if ($day-of-week = 0) then 'søndag'
                                                  else if ($day-of-week = 1) then 'mandag'
                                                  else if ($day-of-week = 2) then 'tirsdag'
                                                  else if ($day-of-week = 3) then 'onsdag'
                                                  else if ($day-of-week = 4) then 'torsdag'
                                                  else if ($day-of-week = 5) then 'fredag'
                                                  else if ($day-of-week = 6) then 'lørdag'
                                                  else $day-of-week"/>
    <xsl:variable name="day-of-month" select="xs:integer($day)"/>
    
    <xsl:variable name="identifier-with-date" select="concat($identifier, substring($year,3), $month, $day)"/>
    
    <xsl:variable name="article-part-mapping" as="element()*">
        <map newspaper-title="Aftenposten" department="A-magasinet" part-name="A-magasinet"/>
        <map newspaper-title="Aftenposten" section="Kultur" part-number="2"/>
        <map newspaper-title="Aftenposten" section="Sport" part-number="2"/>
    </xsl:variable>
    
    <xsl:variable name="section-name-mapping" as="element()*">
        <map section="Nyhet" use="Nyheter"/>
        <map section="Striper_spill" use="Striper &amp; spill"/>
        <map section="Navneside" use="Navn"/>
        <map section="Cover" use="Omslag"/>
    </xsl:variable>
    
    <xsl:variable name="default-section" select="'Nyheter'"/>
    
    <!-- by default, copy everything -->
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- main entry point (npx:npexchange is the root element) -->
    <xsl:template match="npx:npexchange">
        <xsl:variable name="title-long" select="concat($title, ', ', $day-of-week-name, ' ', $day-of-month, '. ', $month-name, ' ', $year)"/>
        
        <dtbook version="2005-3" xml:lang="no">
            <head>
                <meta name="dtb:uid" content="{$identifier-with-date}"/>
                <meta name="dc:Identifier" content="{$identifier-with-date}"/>
                <meta name="dc:Title" content="{$title-long}"/>
                <meta name="dc:Publisher" content="NLB"/>
                <meta name="dc:Language" content="nb-NO"/>
                <meta name="dc:Date" content="{$date}"/>
                <meta name="generator" content="schibsted-to-dtbook.xsl"/>
                <meta name="description" content="Input document for Daisy production"/>
            </head>
            <book>
                <frontmatter>
                    <doctitle>
                        <xsl:value-of select="$title-long"/>
                    </doctitle>
                    <level1 class="preface" id="about">
                        <h1>
                            <xsl:text>Om NLBs lydversjon av </xsl:text>
                            <xsl:value-of select="$title"/>
                        </h1>
                        <p>Lydversjonen er basert på det redaksjonelle innholdet i papirutgaven av avisen.</p>
                        <p>Lydversjonen er tilgjengelig syv dager i uken, enten som nedlastbar fil eller gjennom strømming.
                            Lydversjonen distribueres også på CD, men da bare for de utgavene som kommer på ukedager. CD-en vil normalt komme per post én dag etter
                            papirutgaven. Hvis du velger å høre på avisen ved å laste ned eller strømme, vil du få lydversjonen samtidig med at andre lesere får
                            papirutgaven.</p>
                        <p>Den automatiske produksjonen av lydversjonen av avisen medfører at navn på artikkelforfattere av og til presenteres på en feilaktig eller misvisende måte.</p>
                        <p>Det kan også forekomme andre feil i lydversjonen, enten som et
                            resultat av den automatiske produksjonen, eller på grunn av
                            svakheter i det datamaterialet som danner grunnlaget for NLBs
                            produksjon. Vi beklager dette, og jobber kontinuerlig med å forbedre
                            produktet.</p>
                        <p>Kontakt oss, fortrinnsvis på lydavis@nlb.no, dersom du har spørsmål
                            om lydavisen.</p>
                    </level1>
                </frontmatter>
                <bodymatter>
                    
                    <xsl:variable name="all-articles" select="npx:article" as="element()*"/>
                    
                    <xsl:variable name="non-empty-articles" as="element()*">
                        <!-- filter out articles without content -->
                        <xsl:for-each select="$all-articles">
                            <xsl:variable name="main-npdoc" select="npx:articleparts/npx:articlepart[1]/npx:data/npdoc:npdoc"/>
                            <xsl:variable name="other-npdocs" select="npx:articleparts/npx:articlepart[position() gt 1 and not(npx:article_part_type_id='Sitat') and normalize-space(npx:data/npdoc:npdoc)]/npx:data/npdoc:npdoc"/>
                            <xsl:if test="exists(($main-npdoc | $other-npdocs)/*//text()[normalize-space()] except $main-npdoc/(npdoc:headline | npdoc:madmansrow | npdoc:pagedateline)//text()[normalize-space()])">
                                <xsl:sequence select="."/>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    
                    <xsl:variable name="unique-articles" as="element()*">
                        <xsl:for-each select="distinct-values($non-empty-articles/f:article-headline(npx:articleparts/npx:articlepart[1]/npx:data/npdoc:npdoc))">
                            <xsl:variable name="headline" select="."/>
                            
                            <!-- get all revisions of this article, and sort them by updated_date (sortable ISO datetime string) -->
                            <xsl:variable name="article-revisions" as="element()*">
                                <xsl:for-each select="$non-empty-articles[f:article-headline(npx:articleparts/npx:articlepart[1]/npx:data/npdoc:npdoc) = $headline]">
                                    <xsl:sort select="npx:updated_date/string(.)"/>
                                    <xsl:sequence select="."/>
                                </xsl:for-each>
                            </xsl:variable>
                            
                            <!-- select the revision that most recently updated -->
                            <xsl:sequence select="$article-revisions[last()]"/>
                        </xsl:for-each>
                    </xsl:variable>
                    
                    <xsl:variable name="unique-articles-sorted" as="element()*">
                        <!-- sort by page number, then id -->
                        <xsl:for-each select="$unique-articles">
                            <xsl:sort select="npx:page_id/@firstPagin/xs:integer(.)"/>
                            <xsl:sort select="npx:page_id/@id"/>
                            <xsl:sequence select="."/>
                        </xsl:for-each>
                    </xsl:variable>
                    
                    <!-- for each part -->
                    <xsl:variable name="part-ids" select="distinct-values($unique-articles-sorted/f:part-id(.))"/>
                    <xsl:for-each select="$part-ids">
                        <xsl:sort select="."/>
                        <xsl:variable name="part-id" select="." as="xs:string"/>
                        <xsl:variable name="part-headline" select="f:part-headline($part-id, $unique-articles-sorted)"/>
                        <xsl:variable name="page-type" select="if (position() = 1) then 'normal' else 'special'"/>
                        <xsl:choose>
                            <xsl:when test="$part-headline">
                                <level1 id="{$part-id}" class="part">
                                    <xsl:if test="$part-headline">
                                        <h1><xsl:value-of select="$part-headline"/></h1>
                                    </xsl:if>
                                    
                                    <xsl:call-template name="part">
                                        <xsl:with-param name="part-id" select="$part-id"/>
                                        <xsl:with-param name="part-articles" select="$unique-articles-sorted[f:part-id(.) = $part-id]"></xsl:with-param>
                                        <xsl:with-param name="level" select="2"/>
                                        <xsl:with-param name="page-type" select="$page-type"/>
                                    </xsl:call-template>
                                </level1>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:call-template name="part">
                                    <xsl:with-param name="part-id" select="$part-id"/>
                                    <xsl:with-param name="part-articles" select="$unique-articles-sorted[f:part-id(.) = $part-id]"></xsl:with-param>
                                    <xsl:with-param name="level" select="1"/>
                                    <xsl:with-param name="page-type" select="$page-type"/>
                                </xsl:call-template>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                    
                </bodymatter>
            </book>
        </dtbook>
    </xsl:template>
    
    <xsl:template name="part">
        <xsl:param name="part-id" as="xs:string"/>
        <xsl:param name="part-articles" as="element()*"/>
        <xsl:param name="level" as="xs:integer"/>
        <xsl:param name="page-type" as="xs:string"/>
        
        <!-- list of articles that should start with a pagenum -->
        <xsl:variable name="paged-articles" as="element()*">
            <xsl:for-each select="distinct-values($part-articles/npx:page_id/@firstPagin/xs:integer(.))">
                <xsl:sequence select="($part-articles[npx:page_id/@firstPagin/xs:integer(.) = current()])[1]"/>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:for-each-group select="$part-articles" group-adjacent="if (exists(npx:page_id/@section)) then npx:page_id/@section else $default-section">
            <xsl:element name="level{$level}">
                <xsl:attribute name="id" select="concat($part-id, '_section-', position())"/>
                <xsl:element name="h{$level}"><xsl:value-of select="f:section-headline(current-grouping-key())"/></xsl:element>
                
                <xsl:variable name="section-articles" select="current-group()"/>
                <xsl:variable name="pages" select="distinct-values($section-articles/npx:page_id/@firstPagin/xs:integer(.))"/>
                
                <!-- for each page -->
                <xsl:for-each select="$pages">
                    <xsl:sort select="."/>
                    <xsl:variable name="page-nr" select="."/>
                    
                    <xsl:variable name="pageArticles" select="$section-articles[npx:page_id/@firstPagin = string($page-nr)]"/>
                    
                    <!-- for each article -->
                    <xsl:for-each select="$pageArticles">
                        <xsl:call-template name="article">
                            <xsl:with-param name="page-nr" select="if (. intersect $paged-articles) then $page-nr else ()"/>
                            <xsl:with-param name="level" select="$level + 1"/>
                            <xsl:with-param name="page-type" select="$page-type"/>
                        </xsl:call-template>
                    </xsl:for-each>
                </xsl:for-each>
            </xsl:element>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:template name="article">
        <xsl:param name="page-nr" as="xs:integer?"/>
        <xsl:param name="level" as="xs:integer"/>
        <xsl:param name="page-type" as="xs:string"/>
        
        <xsl:variable name="main-npdoc" select="npx:articleparts/npx:articlepart[1]/npx:data/npdoc:npdoc"/>
        <xsl:variable name="other-npdocs" select="npx:articleparts/npx:articlepart[position() gt 1 and not(npx:article_part_type_id='Sitat') and normalize-space(npx:data/npdoc:npdoc)]/npx:data/npdoc:npdoc"/>
        
        <xsl:variable name="level3-id" select="concat('uuid_', @uuid)"/>
        <xsl:element name="level{$level}">
            <xsl:attribute name="id" select="$level3-id"/>
            
            <xsl:if test="$page-nr">
                <pagenum id="page_{@uuid}_{$page-nr}" page="{$page-type}"><xsl:value-of select="$page-nr"/></pagenum>
            </xsl:if>
            
            <xsl:call-template name="article-head">
                <xsl:with-param name="npdoc" select="$main-npdoc"/>
                <xsl:with-param name="level" select="$level"/>
            </xsl:call-template>
            
            <xsl:for-each-group select="$main-npdoc/npdoc:body/*[normalize-space()]" group-starting-with="*[starts-with(local-name(), 'subheadline')]">
                <xsl:variable name="level4-id" select="concat($level3-id,'-main-',position())"/>
                <xsl:choose>
                    <xsl:when test="current-group()[1][starts-with(local-name(), 'subheadline')] and count(current-group()) gt 1">
                        <xsl:element name="level{$level + 1}">
                            <xsl:attribute name="id" select="$level4-id"/>
                            
                            <xsl:apply-templates select="current-group()">
                                <xsl:with-param name="level" select="$level + 1" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:element>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()">
                            <xsl:with-param name="headline-as-paragraph" select="true()" tunnel="yes"/>
                            <xsl:with-param name="level" select="$level + 1" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
            <xsl:for-each select="$other-npdocs">
                <xsl:variable name="level4-id" select="concat($level3-id,'-other-',position())"/>
                <xsl:choose>
                    <xsl:when test="exists((npdoc:headline | npdoc:madmansrow | npdoc:pagedateline)[normalize-space()]) and exists(* except (npdoc:headline | npdoc:madmansrow | npdoc:pagedateline))">
                        <xsl:element name="level{$level + 1}">
                            <xsl:attribute name="id" select="$level4-id"/>
                            
                            <xsl:call-template name="article-head">
                                <xsl:with-param name="npdoc" select="."/>
                                <xsl:with-param name="level" select="$level + 1"/>
                            </xsl:call-template>
                            
                            <xsl:for-each-group select="npdoc:body/*[normalize-space()]" group-starting-with="*[starts-with(local-name(), 'subheadline')]">
                                <xsl:choose>
                                    <xsl:when test="current-group()[1][starts-with(local-name(), 'subheadline')] and count(current-group()) gt 1">
                                        <xsl:element name="level{$level + 2}">
                                            <xsl:attribute name="id" select="concat($level4-id, '-section-', position())"/>
                                            <xsl:apply-templates select="current-group()">
                                                <xsl:with-param name="level" select="$level + 2" tunnel="yes"/>
                                            </xsl:apply-templates>
                                        </xsl:element>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:apply-templates select="current-group()">
                                            <xsl:with-param name="headline-as-paragraph" select="true()" tunnel="yes"/>
                                            <xsl:with-param name="level" select="$level + 2" tunnel="yes"/>
                                        </xsl:apply-templates>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each-group>
                        </xsl:element>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each-group select="(*[not(self::npdoc:body) and normalize-space() != ''], npdoc:body/*[normalize-space()])" group-starting-with="*[starts-with(local-name(), 'subheadline')]">
                            <xsl:choose>
                                <xsl:when test="current-group()[1][starts-with(local-name(), 'subheadline')] and count(current-group()) gt 1">
                                    <xsl:element name="level{$level + 1}">
                                        <xsl:attribute name="id" select="concat($level4-id, '-section-', position())"/>
                                        <xsl:apply-templates select="current-group()">
                                            <xsl:with-param name="level" select="$level + 1" tunnel="yes"/>
                                        </xsl:apply-templates>
                                    </xsl:element>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:apply-templates select="current-group()">
                                        <xsl:with-param name="headline-as-paragraph" select="true()" tunnel="yes"/>
                                        <xsl:with-param name="level" select="$level + 1" tunnel="yes"/>
                                    </xsl:apply-templates>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each-group>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:element>
    </xsl:template>
    
    <xsl:template name="article-head">
        <xsl:param name="npdoc" as="element()"/>
        <xsl:param name="level" as="xs:integer"/>
        
        <xsl:call-template name="headline">
            <xsl:with-param name="npdoc" select="$npdoc"/>
            <xsl:with-param name="level" select="$level"/>
        </xsl:call-template>
        <xsl:apply-templates select="$npdoc/npdoc:drophead"/>
        <xsl:apply-templates select="$npdoc/npdoc:preleadin"/>
        <xsl:apply-templates select="$npdoc/npdoc:leadin"/>
        <xsl:apply-templates select="$npdoc/npdoc:dateline"/>
    </xsl:template>
    
    <xsl:template name="headline">
        <xsl:param name="npdoc" as="element()"/>
        <xsl:param name="level" as="xs:integer"/>
        <xsl:param name="headline-as-paragraph" select="false()" as="xs:boolean"/>
        
        <xsl:variable name="headline" select="($npdoc/npdoc:headline/npdoc:p[normalize-space()])[1]" as="element()?"/>
        <xsl:variable name="subtitles" select="($npdoc/npdoc:headline/npdoc:p[normalize-space()])[position() gt 1]" as="element()*"/>
        <xsl:variable name="madmansrow" select="$npdoc/npdoc:madmansrow[normalize-space()]" as="element()?"/>
        <xsl:variable name="pagedateline" select="$npdoc/npdoc:pagedateline[normalize-space()]" as="element()?"/>
        
        <xsl:choose>
            <xsl:when test="count(($headline, $madmansrow, $pagedateline)) gt 0">
                <xsl:element name="{if ($headline-as-paragraph) then 'p' else concat('h', $level)}" exclude-result-prefixes="#all">
                    <xsl:apply-templates select="$madmansrow">
                        <xsl:with-param name="headline-as-paragraph" select="$headline-as-paragraph" tunnel="yes"/>
                    </xsl:apply-templates>
                    <xsl:apply-templates select="$pagedateline">
                        <xsl:with-param name="headline-as-paragraph" select="$headline-as-paragraph" tunnel="yes"/>
                    </xsl:apply-templates>
                    
                    <xsl:value-of select="normalize-space($headline)"/>
                </xsl:element>
            </xsl:when>
            <xsl:when test="not(exists($npdoc/ancestor::npx:articlepart/preceding-sibling::npx:articlepart))">
                <!-- articles should always have a headline, use the first sentence, max 100 characters, as fallback -->
                <xsl:element name="{if ($headline-as-paragraph) then 'p' else concat('h', $level)}" exclude-result-prefixes="#all">
                    <xsl:variable name="inferred-headline" select="($npdoc//text()[normalize-space()])[1]"/>
                    <xsl:value-of select="if (string-length($inferred-headline) gt 100) then concat(substring($inferred-headline, 1, 100), '…') else $inferred-headline"/>
                </xsl:element>
            </xsl:when>
        </xsl:choose>
        
        <xsl:for-each select="$subtitles">
            <p class="subtitle"><xsl:value-of select="normalize-space(.)"/></p>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="npdoc:headline">
        <!-- NOTE: headlines are normally not handled here. They are only handled here if there are no body. -->
        
        <xsl:variable name="headline" select="(npdoc:p[normalize-space()])[1]" as="element()?"/>
        <xsl:variable name="subtitles" select="(npdoc:p[normalize-space()])[position() gt 1]" as="element()*"/>
        
        <p class="{f:classes(., 'headline')}">
            <xsl:value-of select="$headline"/>
        </p>
        
        <xsl:for-each select="$subtitles">
            <p class="{f:classes(., 'subtitle')}">
                <xsl:value-of select="."/>
            </p>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="npdoc:madmansrow">
        <xsl:param name="headline-as-paragraph" select="true()" as="xs:boolean" tunnel="yes"/>
        
        <xsl:variable name="madmansrow" select="normalize-space(.)"/>
        
        <xsl:if test="$madmansrow">
            <xsl:element name="{if ($headline-as-paragraph) then 'p' else 'span'}">
                <xsl:attribute name="class" select="'madmansrow'"/>
                <xsl:value-of select="$madmansrow"/>
                
                <xsl:if test="not(ends-with($madmansrow, ':')) and exists(../npdoc:headline[normalize-space()])">
                    <xsl:text>:</xsl:text>
                </xsl:if>
            </xsl:element>
            
            <xsl:if test="exists(../npdoc:headline)">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:pagedateline">
        <xsl:param name="headline-as-paragraph" select="true()" as="xs:boolean" tunnel="yes"/>
        
        <xsl:variable name="pagedateline" select="normalize-space(.)"/>
        
        <xsl:if test="$pagedateline">
            <xsl:element name="{if ($headline-as-paragraph) then 'p' else 'span'}">
                <xsl:attribute name="class" select="'pagedateline'"/>
                <xsl:value-of select="$pagedateline"/>
                
                <xsl:if test="not(ends-with($pagedateline, ':')) and exists(../npdoc:headline)">
                    <xsl:text>:</xsl:text>
                </xsl:if>
            </xsl:element>
            
            <xsl:if test="exists(../npdoc:headline)">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:*/@customName">
        <xsl:attribute name="class" select="f:classes(parent::*, ())"/>
    </xsl:template>
    
    <xsl:function name="f:classes">
        <xsl:param name="context" as="element()"/>
        <xsl:param name="classes" as="xs:string*"/>
        <xsl:variable name="customName-class" select="if ($context/@customName) then replace(normalize-space(lower-case($context/@customName)),'[^a-z]','_') else ()" as="xs:string?"/>
        
        <xsl:value-of select="string-join(($classes, $customName-class), ' ')"/>
    </xsl:function>
    
    <xsl:template match="npdoc:p">
        <xsl:if test="normalize-space()">
            <p><xsl:apply-templates select="@* | node()"/></p>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:preleadin">
        <xsl:if test="normalize-space()">
            <div class="{f:classes(., 'preleadin')}">
                <xsl:apply-templates select="node()"/>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:leadin">
        <xsl:if test="normalize-space()">
            <div class="{f:classes(., 'leadin')}">
                <xsl:apply-templates select="node()"/>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:drophead">
        <xsl:if test="normalize-space()">
            <div class="{f:classes(., 'drophead')}">
                <xsl:apply-templates select="node()"/>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:dateline">
        <xsl:if test="normalize-space()">
            <div class="{f:classes(., 'dateline')}">
                <xsl:apply-templates select="node()"/>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:i">
        <xsl:if test="normalize-space()">
            <em>
                <xsl:apply-templates select="@* | node()"/>
            </em>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:b">
        <xsl:if test="normalize-space()">
            <strong>
                <xsl:apply-templates select="@* | node()"/>
            </strong>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:u">
        <xsl:if test="normalize-space()">
            <span class="{f:classes(., 'underline')}">
                <xsl:apply-templates select="node()"/>
            </span>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:sub">
        <xsl:if test="normalize-space()">
            <sub>
                <xsl:apply-templates select="@* | node()"/>
            </sub>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:sup">
        <xsl:if test="normalize-space()">
            <sup>
                <xsl:apply-templates select="@* | node()"/>
            </sup>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:a">
        <xsl:if test="normalize-space()">
            <a>
                <xsl:apply-templates select="@* | node()"/>
            </a>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:caption">
        <xsl:if test="normalize-space()">
            <div class="{f:classes(., 'caption')}">
                <xsl:text>Bildetekst: </xsl:text>
                <xsl:apply-templates select="node()"/>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:*[starts-with(local-name(), 'subheadline') and not(exists(ancestor::npdoc:body))]">
        <!-- treat subheadline as a paragraph if it's not inside the body -->
        <xsl:if test="normalize-space()">
            <p><xsl:apply-templates select="@* | node()"/></p>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="npdoc:*[starts-with(local-name(), 'subheadline') and exists(ancestor::npdoc:body)]">
        <xsl:param name="headline-as-paragraph" select="false()" tunnel="yes"/>
        <xsl:param name="level" as="xs:integer" tunnel="yes"/>
        
        <xsl:choose>
            <xsl:when test="$headline-as-paragraph">
                <p class="{f:classes(., 'subheadline')}">
                    <xsl:if test="@customName">
                        <span class="customName">
                            <xsl:value-of select="@customName"/>
                            <xsl:text>: </xsl:text>
                        </span>
                    </xsl:if>
                    <xsl:apply-templates select="node()"/>
                </p>
                
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="h{$level}">
                    <xsl:apply-templates select="@* | node()"/>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- ========== functions ========== -->
    
    <xsl:function name="f:article-headline" as="xs:string">
        <xsl:param name="npdoc" as="element()"/>
        
        <xsl:variable name="headline" as="element()*">
            <xsl:call-template name="headline">
                <xsl:with-param name="npdoc" select="$npdoc"/>
                <xsl:with-param name="level" select="1"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:value-of select="normalize-space($headline[1])"/>
    </xsl:function>
    
    <xsl:function name="f:section-headline" as="xs:string">
        <xsl:param name="section" as="xs:string"/>
        <xsl:value-of select="($section-name-mapping[@section = $section]/@use, $section)[1]"/>
    </xsl:function>
    
    <xsl:function name="f:part-headline" as="xs:string?">
        <xsl:param name="part-id" as="xs:string"/>
        <xsl:param name="articles" as="element()*"/>
        
        <xsl:variable name="matching-article-part-mapping" select="f:find-article-part-mapping(($articles[f:part-id(.) = $part-id])[1])" as="element()?"/>
        
        <xsl:choose>
            <xsl:when test="exists($matching-article-part-mapping) and $matching-article-part-mapping/@part-name">
                <xsl:value-of select="$matching-article-part-mapping/@part-name"/>
            </xsl:when>
            <xsl:when test="exists($matching-article-part-mapping) and $matching-article-part-mapping/@part-number[not(.='1')]">
                <xsl:value-of select="concat('Del ', $matching-article-part-mapping/@part-number)"/>
            </xsl:when>
            <xsl:when test="count(distinct-values($articles/f:part-id(.))[matches(.,'^part-\d+$')]) gt 1">
                <xsl:value-of select="'Del 1'"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- Nothing: don't split into parts -->
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:part-id" as="xs:string">
        <xsl:param name="article" as="element()"/>
        
        <xsl:variable name="matching-article-part-mapping" select="f:find-article-part-mapping($article)" as="element()?"/>
        
        <xsl:choose>
            <xsl:when test="exists($matching-article-part-mapping)">
                <xsl:value-of select="$matching-article-part-mapping/concat('part-', (@part-number, replace(lower-case(@part-name), '[^a-z0-9]', '_'))[1])"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'part-1'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:find-article-part-mapping" as="element()?">
        <xsl:param name="article" as="element()?"/>
        
        <xsl:if test="exists($article)">
            <xsl:variable name="newspaper-title" select="$title" as="xs:string"/>
            <xsl:variable name="department" select="$article/npx:department_id" as="xs:string"/>
            <xsl:variable name="section" select="($article/npx:page_id/@section, $article/preceding::npx:page_id/@section, $default-section)[1]" as="xs:string"/>
            
            <xsl:variable name="matching-part-mappings" as="element()*">
                <xsl:for-each select="$article-part-mapping">
                    <xsl:if test="(
                        $newspaper-title = @newspaper-title
                        and (@department = $department or string(@department) = '')
                        and (@section = $section or string(@section) = '')
                        )">
                        
                        <xsl:sequence select="."/>
                    </xsl:if>
                </xsl:for-each>
            </xsl:variable>
            <xsl:if test="count($matching-part-mappings) gt 0">
                <xsl:sequence select="$matching-part-mappings[1]"/>
            </xsl:if>
        </xsl:if>
    </xsl:function>
    
</xsl:stylesheet>
