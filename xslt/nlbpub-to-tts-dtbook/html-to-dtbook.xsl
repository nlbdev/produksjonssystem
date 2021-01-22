<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:math="http://www.w3.org/1998/Math/MathML"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="#"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:import href="numeral-conversion.xsl"/>
    <xsl:import href="epub3-vocab.xsl"/>
    
    <xsl:output indent="no" exclude-result-prefixes="#all" doctype-public="-//NISO//DTD dtbook 2005-3//EN"/>
    
    <xsl:param name="remove-invalid-dc-metadata" select="false()" as="xs:boolean"/>

    <!--
    <xsl:variable name="special-classes"
        select="('part','cover','colophon','nonstandardpagination','jacketcopy','frontcover','rearcover','leftflap','rightflap','precedingemptyline','precedingseparator','indented','asciimath','byline','dateline','address','definition','keyboard','initialism','truncation','cite','bdo','quote','exercisenumber','exercisepart','answer','answer_1','box')"/>
    -->

    <xsl:template match="text()|comment()">
        <xsl:copy-of select="."/>
    </xsl:template>

    <xsl:template match="*">
        <xsl:comment select="concat('No template for element: &lt;',name(),string-join(for $a in (@*) return concat(' ',$a/name(),'=&quot;',$a,'&quot;'),''),'&gt;')"/>
    </xsl:template>

    <xsl:template match="html:style"/>

    <xsl:template match="html:script"/>

    <xsl:template name="f:coreattrs">
        <xsl:param name="except" tunnel="yes"/>

        <xsl:copy-of select="(@id|@title|@xml:space)[not(name()=$except)]"/>
        <xsl:call-template name="f:classes-and-types"/>
    </xsl:template>

    <xsl:template name="f:i18n">
        <xsl:param name="except" tunnel="yes"/>

        <xsl:copy-of select="(@dir)[not(name()=$except)]"/>
        <xsl:if test="(@xml:lang|@lang) and not(('xml:lang','lang')=$except)">
            <xsl:attribute name="xml:lang" select="(@xml:lang|@lang)[1]"/>
        </xsl:if>
    </xsl:template>

    <xsl:template name="f:classes-and-types">
        <xsl:param name="classes" select="()" tunnel="yes"/>
        <xsl:param name="except" tunnel="yes" select="()"/>
        <xsl:param name="except-classes" tunnel="yes" select="()"/>

        <xsl:if test="not($except-classes='*')">

            <xsl:variable name="old-classes" select="f:classes(.)"/>

            <xsl:variable name="showin" select="replace($old-classes[matches(.,'^showin-...$')][1],'showin-','')"/>
            <xsl:if test="$showin and not('_showin'=$except)">
                <xsl:attribute name="showin" select="$showin"/>
            </xsl:if>

            <!-- remove classes used for the conversion -->
            <xsl:variable name="old-classes" select="$old-classes[not(starts-with(.,'showin-')) and not(.=('list-style-type-none'))]"/>

            <xsl:if test="not('_class'=$except)">
                <xsl:variable name="epub-type-classes">
                    <xsl:for-each select="f:types(.)[not(matches(.,'(^|:)(front|body|back)matter'))]">
                        <xsl:choose>
                            <xsl:when test=".='cover'">
                                <xsl:sequence select="'jacketcopy'"/>
                            </xsl:when>
                            <xsl:when test=".='z3998:halftitle-page'">
                                <xsl:sequence select="'halftitlepage'"/>
                            </xsl:when>
                            <xsl:when test=".='z3998:title-page'">
                                <xsl:sequence select="'titlepage'"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:sequence select="tokenize(.,':')[last()]"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>

                <xsl:variable name="class-string"
                    select="string-join(distinct-values(($classes, if (preceding-sibling::*[1] intersect preceding-sibling::html:hr[1]) then (if (preceding-sibling::html:hr[1]/tokenize(@class,'\s')='separator') then 'precedingseparator' else 'precedingemptyline') else (), $old-classes, $epub-type-classes)[not(.='') and not(.=$except-classes)]),' ')"/>
                <xsl:if test="not($class-string='')">
                    <xsl:attribute name="class" select="$class-string"/>
                </xsl:if>
            </xsl:if>

        </xsl:if>
    </xsl:template>

    <xsl:template name="f:attrs">
        <xsl:call-template name="f:coreattrs"/>
        <xsl:call-template name="f:i18n"/>
    </xsl:template>

    <xsl:template name="f:attrsrqd">
        <xsl:param name="except" tunnel="yes"/>

        <xsl:copy-of select="(@id|@title|@xml:space)[not(name()=$except)]"/>
        <xsl:call-template name="f:classes-and-types"/>
        <xsl:call-template name="f:i18n"/>
    </xsl:template>

    <xsl:template match="html:html">
        <dtbook version="2005-3">
            <xsl:call-template name="f:attlist.dtbook"/>
            <xsl:apply-templates select="node()">
                <xsl:with-param name="all-ids" select=".//@id" tunnel="yes"/>
            </xsl:apply-templates>
        </dtbook>
    </xsl:template>

    <xsl:template name="f:attlist.dtbook">
        <xsl:call-template name="f:i18n"/>
    </xsl:template>

    <xsl:template match="html:head">
        <head>
            <xsl:call-template name="f:attlist.head"/>
            <meta name="dtb:uid" content="{(html:meta[lower-case(@name)=('dtb:uid','dc:identifier')])[1]/@content}"/>
            <xsl:apply-templates select="node()"/>
        </head>
    </xsl:template>

    <xsl:template match="html:title">
        <meta name="dc:Title" content="{normalize-space(.)}">
            <xsl:call-template name="f:i18n"/>
        </meta>
    </xsl:template>

    <xsl:template name="f:attlist.head">
        <xsl:call-template name="f:i18n"/>
        <xsl:if test="html:link[@rel='profile' and @href]">
            <xsl:attribute name="profile" select="(html:link[@rel='profile'][1])/@href"/>
        </xsl:if>
    </xsl:template>

    <!-- link is disallowed in nordic DTBook -->
    <xsl:template match="html:link">
        <!--<link>
            <xsl:call-template name="f:attlist.link"/>
        </link>-->
    </xsl:template>

    <xsl:template name="f:attlist.link">
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@href|@hreflang|@type|@rel|@media"/>
        <!-- @sizes are dropped -->
    </xsl:template>

    <xsl:template match="html:meta">
        <xsl:if test="not(@http-equiv='Content-Type') and not(@charset) and not(@name='viewport')">
            <xsl:message
                select="concat('removed meta element because it did not contain a name attribute, a content attribute, or for some other reason (',string-join(for $a in (@*) return concat($a/name(),'=&quot;',$a,'&quot;'),' '),')')"
            />
        </xsl:if>
    </xsl:template>

    <xsl:template match="html:meta[@name and @content and not(lower-case(@name)=('viewport','dc:title'))]">
        <xsl:choose>
            <xsl:when test="$remove-invalid-dc-metadata and starts-with(lower-case(@name), 'dc:') and not(matches(lower-case(@name), '^dc:(title|subject|description|type|source|relation|coverage|creator|publisher|contributor|rights|date|format|identifier|language)$'))">
                <xsl:comment>
                    <xsl:text> not allowed in DTBook: </xsl:text>
                    <xsl:text>&lt;meta</xsl:text>
                    <xsl:for-each select="@*">
                        <xsl:value-of select="concat(' ', name(), '=&quot;', ., '&quot;')"/>
                    </xsl:for-each>
                    <xsl:text>/&gt; </xsl:text>
                </xsl:comment>
            </xsl:when>
            <xsl:otherwise>
                <meta>
                    <xsl:call-template name="f:attlist.meta"/>
                </meta>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="f:attlist.meta">
        <xsl:call-template name="f:i18n"/>
        <xsl:copy-of select="@http-equiv"/>
        <xsl:choose>
            <xsl:when test="@name='nordic:guidelines'">
                <xsl:attribute name="name" select="'track:Guidelines'"/>
                <xsl:attribute name="content" select="'2015-1'"/>
            </xsl:when>
            <xsl:when test="@name='nordic:supplier'">
                <xsl:attribute name="name" select="'track:Supplier'"/>
                <xsl:attribute name="content" select="@content"/>
            </xsl:when>
            <xsl:when test="lower-case(@name)='dc:format'">
                <xsl:attribute name="name" select="'dc:Format'"/>
                <xsl:attribute name="content" select="'DTBook'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="name" select="if (starts-with(@name,'dc:')) then concat('dc:',upper-case(substring(@name,4,1)),lower-case(substring(@name,5))) else @name"/>
                <xsl:attribute name="content" select="@content"/>
            </xsl:otherwise>
        </xsl:choose>
        <!-- @charset is dropped -->
    </xsl:template>

    <xsl:template match="html:body">
        <book>
            <xsl:call-template name="f:frontmatter"/>
            <xsl:if test="(html:section | html:article)[f:types(.)=('bodymatter') or not(f:types(.)=('cover','frontmatter','bodymatter','backmatter'))]">
                <xsl:call-template name="f:bodymatter"/>
            </xsl:if>
            <xsl:if test="(html:section | html:article)[f:types(.)=('backmatter')]">
                <xsl:call-template name="f:rearmatter"/>
            </xsl:if>
            <xsl:apply-templates select="*[last()]/following-sibling::node()"/>
        </book>
    </xsl:template>

    <xsl:template name="f:frontmatter">
        <frontmatter>
            <xsl:for-each select="../html:head/html:title[1]/text()">
                <doctitle>
                    <xsl:value-of select="."/>
                </doctitle>
            </xsl:for-each>
            <xsl:for-each select="../html:head/html:meta[@name='dc:creator']/@content">
                <docauthor>
                    <xsl:value-of select="."/>
                </docauthor>
            </xsl:for-each>
            <xsl:apply-templates select="(html:section | html:article)[f:types(.)=('cover','frontmatter')]"/>
        </frontmatter>
    </xsl:template>

    <xsl:template name="f:bodymatter">
        <bodymatter>
            <xsl:apply-templates select="(html:section | html:article)[not(f:types(.)=('cover','frontmatter','backmatter'))]"/>
        </bodymatter>
    </xsl:template>

    <xsl:template name="f:rearmatter">
        <rearmatter>
            <xsl:apply-templates select="(html:section | html:article)[f:types(.)=('backmatter')]"/>
        </rearmatter>
    </xsl:template>

    <xsl:template match="html:section | html:article">
        <xsl:call-template name="f:copy-preceding-comments"/>
        <xsl:variable name="level" select="f:level(.)"/>
        <xsl:element name="level{$level}">
            <xsl:call-template name="f:attlist.level">
                <xsl:with-param name="classes" select="if (self::html:article) then 'article' else ()" tunnel="yes"/>
                <!--<xsl:with-param name="level-classes"
                    select="if ($level &gt; 1) then () else (if (f:types(.)='cover') then 'jacketcopy' else (), for $class in (tokenize(@class,'\s')) return if ($class = ('part','jacketcopy','colophon','nonstandardpagination')) then $class else ())"
                />-->
            </xsl:call-template>

            <xsl:variable name="headline" select="(html:*[matches(local-name(),'^h\d$')])[1]"/>
            <xsl:variable name="initial-pagebreak" select="$headline/following-sibling::*[1][f:types(.)='pagebreak']"/>
            <xsl:variable name="move-pagebreaks" select="not($headline/preceding-sibling::*[1][f:types(.)='pagebreak']) and $headline/following-sibling::*[1][f:types(.)='pagebreak']" as="xs:boolean"/>

            <xsl:if test="$move-pagebreaks">
                <!-- [tpb126] pagenum must not occur directly after hx unless the hx is preceded by a pagenum -->
                <xsl:apply-templates select="$initial-pagebreak"/>
                <xsl:apply-templates select="$headline"/>
            </xsl:if>
            
            <xsl:variable name="nodes" select="if ($move-pagebreaks) then node()[not(. intersect $initial-pagebreak) and not(. intersect $headline)] else node()" as="node()*"/>
            <xsl:for-each-group select="$nodes" group-starting-with="html:h1 | html:h2 | html:h3 | html:h4 | html:h5 | html:h6 | html:section | html:article">
                <xsl:choose>
                    <xsl:when test="current-group()[1][self::html:h1 | self::html:h2 | self::html:h3 | self::html:h4 | self::html:h5 | self::html:h6] and not($headline intersect current-group())">
                        <xsl:element name="level{$level + 1}">
                            <xsl:call-template name="f:attlist.level">
                                <xsl:with-param name="classes" select="if (self::html:article) then 'article' else ()" tunnel="yes"/>
                                <xsl:with-param name="except" select="'id'" tunnel="yes"/>
                            </xsl:call-template>
                            <xsl:apply-templates select="current-group()"/>
                        </xsl:element>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>

        </xsl:element>
    </xsl:template>

    <xsl:template name="f:attlist.level">
        <!--        <xsl:param name="level-classes"/>-->
        <xsl:call-template name="f:attrs">
            <!--            <xsl:with-param name="except-classes" select="'*'" tunnel="yes"/>-->
        </xsl:call-template>
        <!--<xsl:if test="count($level-classes) &gt; 0">
            <xsl:attribute name="class" select="string-join($level-classes,' ')"/>
        </xsl:if>-->
    </xsl:template>
    
    <xsl:template match="math:*">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:if test="self::math:math and not(@display)">
                <xsl:message select="'Warning: MathML element is missing the ''display'' attribute. It will be inferred instead.'"/>
                <xsl:attribute name="display" select="if (f:is-inline(.)) then 'inline' else 'block'"/>
            </xsl:if>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="html:br">
        <br>
            <xsl:call-template name="f:attlist.br"/>
        </br>
    </xsl:template>

    <xsl:template name="f:attlist.br">
        <xsl:call-template name="f:coreattrs"/>
    </xsl:template>

    <xsl:template match="html:p[f:classes(.)='line']">
        <line>
            <xsl:call-template name="f:attlist.line"/>
            <xsl:apply-templates select="node()"/>
        </line>
    </xsl:template>

    <xsl:template name="f:attlist.line">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'line'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:span[f:classes(.)='linenum']">
        <linenum>
            <xsl:call-template name="f:attlist.linenum"/>
            <xsl:apply-templates select="node()"/>
        </linenum>
    </xsl:template>

    <xsl:template name="f:attlist.linenum">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'linenum'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <!-- <address> is not allowed in nordic DTBook. Replacing with p. -->
    <xsl:template match="html:address">
        <xsl:message select="'&lt;address&gt; is not allowed in nordic DTBook. Replacing with p and a &quot;address&quot; class.'"/>
        <p>
            <xsl:call-template name="f:attlist.address"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>

    <!-- <address> is not allowed in nordic DTBook. Replacing with p and a "address" class. -->
    <xsl:template name="f:attlist.address">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'address'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:div">
        <div>
            <xsl:call-template name="f:attlist.div"/>
            <xsl:apply-templates select="node()"/>
        </div>
    </xsl:template>

    <xsl:template name="f:attlist.div">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:*[f:classes(.)='title' and not(parent::html:header[parent::html:body]) and ancestor::html:*/f:types(.)=('z3998:poem','z3998:verse')]">
        <title>
            <xsl:call-template name="f:attlist.title"/>
            <xsl:apply-templates select="node()"/>
        </title>
    </xsl:template>

    <xsl:template name="f:attlist.title">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'title'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:*[f:types(.)='z3998:author' and not(parent::html:header[parent::html:body]) and ancestor::html:*/f:types(.)=('z3998:poem','z3998:verse')]">
        <author>
            <xsl:call-template name="f:attlist.author"/>
            <xsl:apply-templates select="node()"/>
        </author>
    </xsl:template>

    <xsl:template name="f:attlist.author">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'author'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:aside[f:types(.)='z3998:production'] | html:section[f:classes(.)=('frontcover','rearcover','leftflap','rightflap') and parent::*/f:types(.)='cover']">
        <xsl:choose>
            <xsl:when test="ancestor::html:section[f:classes(.)=('frontcover','rearcover','leftflap','rightflap') and parent::*/f:types(.)='cover']">
                <div>
                    <xsl:call-template name="f:attlist.div">
                        <xsl:with-param name="classes" select="if (f:classes(.) = ('render-required','render-optional')) then () else ('render-optional')" tunnel="yes"/>
                    </xsl:call-template>
                    <xsl:apply-templates select="node()"/>
                </div>
            </xsl:when>
            <xsl:otherwise>
                <prodnote>
                    <xsl:call-template name="f:attlist.prodnote"/>
                    <xsl:apply-templates select="node()"/>
                </prodnote>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="f:attlist.prodnote">
        <xsl:param name="all-ids" tunnel="yes" select=".//@id"/>
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="('production','render-required','render-optional')" tunnel="yes"/>
        </xsl:call-template>
        <xsl:choose>
            <xsl:when test="f:classes(.)='render-required'">
                <xsl:attribute name="render" select="'required'"/>
            </xsl:when>
            <xsl:when test="f:classes(.)='render-optional'">
                <xsl:attribute name="render" select="'optional'"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- let's make "optional" the default -->
                <xsl:attribute name="render" select="'optional'"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@id">
            <xsl:variable name="id" select="@id"/>
            <xsl:variable name="img" select="//html:img[replace(@longdesc,'^#','')=$id]"/>
            <xsl:if test="$img">
                <xsl:attribute name="imgref" select="string-join($img/((@id,f:generate-pretty-id(.,$all-ids))[1]),' ')"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="html:aside[f:types(.)='sidebar'] | html:figure[f:types(.)='sidebar']">
        <sidebar>
            <xsl:call-template name="f:attlist.sidebar"/>
            <xsl:apply-templates select="node()"/>
        </sidebar>
    </xsl:template>

    <xsl:template name="f:attlist.sidebar">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'sidebar'" tunnel="yes"/>
        </xsl:call-template>
        <xsl:choose>
            <xsl:when test="self::html:figure">
                <xsl:attribute name="render" select="'required'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="render" select="'optional'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="html:aside[f:types(.)='note'] | html:li[f:types(.)=('rearnote','footnote')]">
        <note>
            <xsl:call-template name="f:attlist.note"/>
            <xsl:choose>
                <xsl:when test="(text()[normalize-space()] | *)/f:is-inline(.) = true()">
                    <p>
                        <xsl:apply-templates select="node()"/>
                    </p>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="node()"/>
                </xsl:otherwise>
            </xsl:choose>
        </note>
    </xsl:template>

    <xsl:template name="f:attlist.note">
        <xsl:call-template name="f:attrsrqd">
            <xsl:with-param name="except-classes" select="'*'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <!-- <annotation> is not allowed in nordic DTBook. Replacing with p. -->
    <xsl:template match="html:aside[f:types(.)='annotation']">
        <xsl:message select="'&lt;annotation&gt; is not allowed in nordic DTBook. Replacing with p and a &quot;annotation&quot; class.'"/>
        <p>
            <xsl:call-template name="f:attlist.annotation"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>

    <!-- <annotation> is not allowed in nordic DTBook. Replacing with p and a "annotation" class. -->
    <xsl:template name="f:attlist.annotation">
        <xsl:call-template name="f:attrsrqd">
            <xsl:with-param name="classes" select="'annotation'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <!-- <epigraph> is not allowed in nordic DTBook. Using p instead. -->
    <xsl:template match="html:aside[f:types(.)='epigraph']">
        <xsl:message select="'&lt;epigraph&gt; is not allowed in nordic DTBook. Using p instead with a epigraph class.'"/>
        <p>
            <xsl:call-template name="f:attlist.epigraph"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>

    <!-- <epigraph> is not allowed in nordic DTBook. Using p instead with a epigraph class. -->
    <xsl:template name="f:attlist.epigraph">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'epigraph'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <!-- <byline> is not allowed in nordic DTBook. Using span instead. -->
    <xsl:template match="html:span[f:classes(.)='byline']">
        <xsl:message select="'&lt;byline&gt; is not allowed in nordic DTBook. Using span instead with a byline class.'"/>
        <span>
            <xsl:call-template name="f:attlist.byline"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <byline> is not allowed in nordic DTBook. Using span instead with a byline class. -->
    <xsl:template name="f:attlist.byline">
        <xsl:call-template name="f:attrs">
            <!--            <xsl:with-param name="except-classes" select="'byline'" tunnel="yes"/>-->
        </xsl:call-template>
    </xsl:template>

    <!-- <dateline> is not allowed in nordic DTBook. Using span instead. -->
    <xsl:template match="html:span[f:classes(.)='dateline']">
        <xsl:message select="'&lt;dateline&gt; is not allowed in nordic DTBook. Using span instead with a dateline class.'"/>
        <span>
            <xsl:call-template name="f:attlist.dateline"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <dateline> is not allowed in nordic DTBook. Using span instead with a dateline class. -->
    <xsl:template name="f:attlist.dateline">
        <xsl:call-template name="f:attrs">
            <!--            <xsl:with-param name="except-classes" select="'dateline'" tunnel="yes"/>-->
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:*[f:classes(.)='linegroup']">
        <linegroup>
            <xsl:call-template name="f:attlist.linegroup"/>
            <xsl:apply-templates select="node()"/>
        </linegroup>
    </xsl:template>

    <xsl:template name="f:attlist.linegroup">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'linegroup'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:*[f:types(.)='z3998:poem'] | html:*[f:types(.)='z3998:verse' and not(ancestor::html:*/f:types(.)='z3998:poem')]">
        <poem>
            <xsl:call-template name="f:attlist.poem"/>
            <xsl:apply-templates select="node()"/>
        </poem>
    </xsl:template>

    <xsl:template name="f:attlist.poem">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="('poem','verse')" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:a">
        <xsl:variable name="a" select="." as="element()"/>
        <xsl:choose>
            <xsl:when test="exists(node())">
                <xsl:for-each-group select="node()" group-adjacent="not(self::html:span and f:classes(.) = 'lic')">
                    <xsl:choose>
                        <xsl:when test="current-grouping-key()">
                            <xsl:variable name="exclude-id" select="exists(current-group()[1]/(preceding-sibling::* | preceding-sibling::text()[normalize-space(.)]))" as="xs:boolean"/>
                            
                            <xsl:for-each select="$a">
                                <xsl:call-template name="f:a">
                                    <xsl:with-param name="children" select="current-group()"/>
                                    <xsl:with-param name="except-classes" select="'lic'" tunnel="yes"/>
                                    <xsl:with-param name="except" select="if ($exclude-id) then 'id' else ()" tunnel="yes"/>
                                </xsl:call-template>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates select="current-group()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each-group>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="f:a"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="f:a">
        <xsl:param name="children" select="node()" as="node()*"/>
        <xsl:if test="count($children[normalize-space()]) + count($children/descendant-or-self::*[tokenize(@epub:type,'\s+') = 'pagebreak']) gt 0">
            <a>
                <xsl:call-template name="f:attlist.a"/>
                <xsl:apply-templates select="$children"/>
            </a>
        </xsl:if>
    </xsl:template>

    <xsl:template name="f:attlist.a">

        <xsl:call-template name="f:attrs">
            <!-- Preserve @target as class attribute. Assumes that only characters that are valid for class names are used. -->
            <xsl:with-param name="classes" select="if (@target) then concat('target-',@target) else ()" tunnel="yes"/>
            <xsl:with-param name="except-classes" select="for $rev in (f:classes(.)[matches(.,'^rev-')]) return $rev" tunnel="yes"/>
        </xsl:call-template>

        <xsl:copy-of select="@type|@href|@hreflang|@rel|@accesskey|@tabindex"/>
        <!-- @download and @media is dropped - they don't have a good equivalent in DTBook -->

        <xsl:choose>
            <xsl:when test="@target='_blank' or matches(@href,'^(\w+:|/)')">
                <xsl:attribute name="external" select="'true'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="external" select="'false'"/>
            </xsl:otherwise>
        </xsl:choose>

        <xsl:if test="f:classes(.)[matches(.,'^rev-')]">
            <xsl:attribute name="rev" select="replace((f:classes(.)[matches(.,'^rev-')])[1],'^rev-','')"/>
        </xsl:if>

    </xsl:template>

    <xsl:template match="html:em">
        <em>
            <xsl:call-template name="f:attlist.em"/>
            <xsl:apply-templates select="node()"/>
        </em>
    </xsl:template>

    <xsl:template name="f:attlist.em">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:strong">
        <strong>
            <xsl:call-template name="f:attlist.strong"/>
            <xsl:apply-templates select="node()"/>
        </strong>
    </xsl:template>

    <xsl:template name="f:attlist.strong">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <!-- <dfn> is not allowed in nordic DTBook. Replacing with span. -->
    <xsl:template match="html:dfn">
        <xsl:message select="'&lt;dfn&gt; is not allowed in nordic DTBook. Replacing with span and a &quot;definition&quot; class.'"/>
        <span>
            <xsl:call-template name="f:attlist.dfn"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <dfn> is not allowed in nordic DTBook. Replacing with span and a "definition" class. -->
    <xsl:template name="f:attlist.dfn">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'definition'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <!-- <kbd> is not allowed in nordic DTBook. Replacing with code. -->
    <xsl:template match="html:kbd">
        <xsl:message select="'&lt;kbd&gt; is not allowed in Nordic DTBook. Replacing with &lt;code&gt; and a &quot;keyboard&quot; class.'"/>
        <code>
            <xsl:call-template name="f:attlist.kbd"/>
            <xsl:apply-templates select="node()"/>
        </code>
    </xsl:template>

    <!-- <kbd> is not allowed in nordic DTBook. Replacing with code and a "keyboard" class. -->
    <xsl:template name="f:attlist.kbd">
        <xsl:attribute name="xml:space" select="'preserve'"/>
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'keyboard'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:code">
        <code>
            <xsl:call-template name="f:attlist.code"/>
            <xsl:apply-templates select="node()"/>
        </code>
    </xsl:template>

    <xsl:template name="f:attlist.code">
        <xsl:attribute name="xml:space" select="'preserve'"/>
        <xsl:call-template name="f:attrs"/>
        <xsl:call-template name="f:i18n"/>
    </xsl:template>

    <xsl:template match="html:pre">
        <p>
            <xsl:call-template name="f:attlist.pre"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>

    <xsl:template name="f:attlist.pre">
        <xsl:call-template name="f:attrs"/>
        <xsl:call-template name="f:i18n"/>
        <xsl:attribute name="xml:space" select="'preserve'"/>
    </xsl:template>

    <!-- <samp> is not allowed in nordic DTBook. Replacing with code. -->
    <xsl:template match="html:samp">
        <xsl:message select="'&lt;samp&gt; is not allowed in nordic DTBook. Replacing with code and a &quot;example&quot; class.'"/>
        <code>
            <xsl:call-template name="f:attlist.samp"/>
            <xsl:apply-templates select="node()"/>
        </code>
    </xsl:template>

    <!-- <samp> is not allowed in nordic DTBook. Replacing with code and a "example" class. -->
    <xsl:template name="f:attlist.samp">
        <xsl:attribute name="xml:space" select="'preserve'"/>
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'example'" tunnel="yes"/>
        </xsl:call-template>
        <xsl:call-template name="f:i18n"/>
    </xsl:template>

    <!-- <cite> is not allowed in nordic DTBook. Using span instead. -->
    <xsl:template match="html:cite">
        <xsl:message select="'&lt;cite&gt; is not allowed in nordic DTBook. Using span instead with a cite class.'"/>
        <span>
            <xsl:call-template name="f:attlist.cite"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <cite> is not allowed in nordic DTBook. Using span instead with a cite class. -->
    <xsl:template name="f:attlist.cite">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'cite'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <!-- abbr is disallowed in nordic dtbooks, using span instead -->
    <xsl:template match="html:abbr[f:types(.)='z3998:truncation']">
        <span>
            <xsl:call-template name="f:attlist.abbr"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <xsl:template name="f:attlist.abbr">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <!-- acronym is disallowed in nordic dtbooks, using span instead -->
    <xsl:template match="html:abbr">
        <span>
            <xsl:call-template name="f:attlist.acronym"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- acronym is disallowed in nordic dtbooks, using span instead and thus not setting the pronounce attribute -->
    <xsl:template name="f:attlist.acronym">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="if (not(f:types(.)='z3998:initialism')) then 'acronym' else ()" tunnel="yes"/>
        </xsl:call-template>
        <!--<xsl:if test="">
            <xsl:attribute name="pronounce" select="if (f:types(.)='z3998:initialism') then 'yes' else 'no'"/>
        </xsl:if>-->
    </xsl:template>

    <xsl:template match="html:sub">
        <sub>
            <xsl:call-template name="f:attlist.sub"/>
            <xsl:apply-templates select="node()"/>
        </sub>
    </xsl:template>

    <xsl:template name="f:attlist.sub">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:sup">
        <sup>
            <xsl:call-template name="f:attlist.sup"/>
            <xsl:apply-templates select="node()"/>
        </sup>
    </xsl:template>

    <xsl:template name="f:attlist.sup">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:span">
        <span>
            <xsl:call-template name="f:attlist.span"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <xsl:template name="f:attlist.span">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <!-- <bdo> is not allowed in nordic DTBook. Replacing with span. -->
    <xsl:template match="html:bdo">
        <xsl:message select="'&lt;bdo&gt; is not allowed in nordic DTBook. Replacing with span and a &quot;bdo-dir-{@dir}&quot; class.'"/>
        <span>
            <xsl:call-template name="f:attlist.bdo"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <bdo> is not allowed in nordic DTBook. Replacing with span and a "bdo-dir-{@dir}" class. -->
    <xsl:template name="f:attlist.bdo">
        <xsl:call-template name="f:coreattrs">
            <xsl:with-param name="classes" select="('bdo', if (@dir and not(@dir='')) then concat('bdo-dir-',@dir) else ())" tunnel="yes"/>
        </xsl:call-template>
        <xsl:call-template name="f:i18n"/>
    </xsl:template>

    <!-- <sent> not allowed in nordic guidelines, using <span> instead -->
    <xsl:template match="html:span[f:types(.)='z3998:sentence']">
        <span>
            <xsl:call-template name="f:attlist.sent"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <sent> not allowed in nordic guidelines, using <span> instead and including the 'sentence' type as a class -->
    <!--            <xsl:with-param name="except-classes" select="'sentence'" tunnel="yes"/>-->
    <xsl:template name="f:attlist.sent">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <!-- <w> is not allowed in nordic DTBook. Using span instead. -->
    <xsl:template match="html:span[f:types(.)='z3998:word' and not(f:types(.)='z3998:sentence')]">
        <xsl:message select="'&lt;w&gt; is not allowed in nordic DTBook. Using span instead with a &quot;word&quot; class.'"/>
        <span>
            <xsl:call-template name="f:attlist.w"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <w> is not allowed in nordic DTBook. Using span instead with a "word" class. -->
    <xsl:template name="f:attlist.w">
        <xsl:call-template name="f:attrs">
            <!--            <xsl:with-param name="except-classes" select="'word'" tunnel="yes"/>-->
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:span[f:types(.)='pagebreak'] | html:div[f:types(.)='pagebreak']">
        <xsl:choose>
            <xsl:when test="ancestor::html:td">
                <xsl:message select="'Moving pagenum in table cell before current row for DTBook conformance.'"/>
            </xsl:when>
            <xsl:otherwise>
                <pagenum>
                    <xsl:call-template name="f:attlist.pagenum"/>
                    <xsl:value-of select="@title"/>
                </pagenum>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="f:attlist.pagenum">
        <xsl:call-template name="f:attrsrqd">
            <xsl:with-param name="except" select="'title'" tunnel="yes"/>
            <xsl:with-param name="except-classes" select="('page-front','page-normal','page-special','pagebreak')" tunnel="yes"/>
        </xsl:call-template>
        <xsl:attribute name="page" select="replace((f:classes(.)[starts-with(.,'page-')],'page-normal')[1], '^page-', '')"/>
    </xsl:template>

    <xsl:template match="html:a[f:types(.)='noteref']">
        <noteref>
            <xsl:call-template name="f:attlist.noteref"/>
            <xsl:apply-templates select="node()"/>
        </noteref>
    </xsl:template>

    <xsl:template name="f:attlist.noteref">
        <xsl:if test="@class or f:types(.)[not(.='noteref')]">
            <xsl:message select="'the class attribute on a noteref was dropped since it is not allowed in Nordic DTBook.'"/>
        </xsl:if>
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'*'" tunnel="yes"/>
        </xsl:call-template>
        <xsl:attribute name="idref" select="@href"/>
        <xsl:copy-of select="@type"/>
    </xsl:template>

    <!-- <annoref> is not allowed in nordic DTBook. Replacing with span. -->
    <xsl:template match="html:a[f:types(.)='annoref']">
        <xsl:message select="'&lt;annoref&gt; is not allowed in nordic DTBook. Replacing with span and a &quot;annoref&quot; class.'"/>
        <span>
            <xsl:call-template name="f:attlist.annoref"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <annoref> is not allowed in nordic DTBook. Replacing with span and a "annoref" class. -->
    <xsl:template name="f:attlist.annoref">
        <xsl:call-template name="f:attrs">
            <!--            <xsl:with-param name="except-classes" select="'annoref'" tunnel="yes"/>-->
        </xsl:call-template>
        <!--<xsl:attribute name="idref" select="@href"/>
        <xsl:copy-of select="@type"/>-->
    </xsl:template>

    <!-- <q> is not allowed in nordic DTBook. Replacing with span. -->
    <xsl:template match="html:q">
        <xsl:message select="'&lt;q&gt; is not allowed in nordic DTBook. Replacing with span and a &quot;quote&quot; class.'"/>
        <span>
            <xsl:call-template name="f:attlist.q"/>
            <xsl:apply-templates select="node()"/>
        </span>
    </xsl:template>

    <!-- <q> is not allowed in nordic DTBook. Replacing with span and a "quote" class. -->
    <xsl:template name="f:attlist.q">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'quote'" tunnel="yes"/>
        </xsl:call-template>
        <!--        <xsl:copy-of select="@cite"/>-->
    </xsl:template>

    <xsl:template match="html:img">
        <img>
            <xsl:call-template name="f:attlist.img"/>
            <xsl:apply-templates select="node()"/>
        </img>
    </xsl:template>

    <xsl:template name="f:attlist.img">
        <xsl:param name="all-ids" tunnel="yes" select=".//@id"/>
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@src|@alt|@longdesc|@height|@width"/>
        <xsl:if test="not(@id)">
            <xsl:attribute name="id" select="f:generate-pretty-id(.,$all-ids)"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="html:figure[f:classes(.)='image']">
        <xsl:choose>
            <xsl:when test="parent::html:figure[f:classes(.)='image-series']">
                <xsl:apply-templates select="html:img"/>
                <xsl:apply-templates select="html:figcaption"/>
                <xsl:apply-templates select="node()[not(self::html:img or self::html:figcaption)]"/>
            </xsl:when>
            <xsl:otherwise>
                <imggroup>
                    <xsl:call-template name="f:attlist.imggroup"/>
                    <xsl:apply-templates select="html:img"/>
                    <xsl:apply-templates select="html:figcaption"/>
                    <xsl:apply-templates select="node()[not(self::html:img or self::html:figcaption)]"/>
                </imggroup>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="html:figure[f:classes(.)='image-series']">
        <imggroup>
            <xsl:call-template name="f:attlist.imggroup"/>
            <xsl:apply-templates select="node()"/>
        </imggroup>
    </xsl:template>

    <xsl:template name="f:attlist.imggroup">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="('image-series','image')" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:p">
        <xsl:variable name="precedinghr" select="preceding-sibling::*[1] intersect preceding-sibling::html:hr[1]"/>
        <p>
            <xsl:call-template name="f:attlist.p">
                <xsl:with-param name="classes" select="if ($precedinghr) then (if ($precedinghr/tokenize(@class,'\s')='separator') then 'precedingseparator' else 'precedingemptyline') else ()"
                    tunnel="yes"/>
            </xsl:call-template>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>

    <xsl:template name="f:attlist.p">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:hr"/>

    <!-- <covertitle> is not allowed in nordic DTBook. Using p instead. -->
    <xsl:template match="html:*[f:types(.)='covertitle' and parent::html:header[parent::html:body]]">
        <xsl:message select="'&lt;covertitle&gt; is not allowed in nordic DTBook, dropping it...'"/>
    </xsl:template>

    <!-- <covertitle> is not allowed in nordic DTBook. Using p instead with a "covertitle" class. -->
    <xsl:template name="f:attlist.covertitle">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'covertitle'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:h1 | html:h2 | html:h3 | html:h4 | html:h5 | html:h6">
        <xsl:choose>
            <xsl:when test="parent::*/f:types(.)=('sidebar','z3998:poem','z3998:verse') or parent::*/f:classes(.)='linegroup'">
                <hd>
                    <xsl:call-template name="f:attlist.h"/>
                    <xsl:apply-templates select="node()"/>
                </hd>
            </xsl:when>
            <xsl:when test="ancestor::html:section[f:classes(.)=('frontcover','rearcover','leftflap','rightflap') and exists(html:h2 | html:h3 | html:h4 | html:h5 | html:h6)]">
                <!-- hX must be in a levelX, so we turn this into a p instead -->
                <p>
                    <xsl:call-template name="f:attlist.h"/>
                    <xsl:apply-templates select="node()"/>
                </p>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="h{f:level(.)}">
                    <xsl:call-template name="f:attlist.h"/>
                    <xsl:apply-templates select="node()"/>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="f:attlist.h">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="text()[ancestor::html:h1 | ancestor::html:h2 | ancestor::html:h3 | ancestor::html:h4 | ancestor::html:h5 | ancestor::html:h6]">
        <!-- normalize space in headlines -->
        <xsl:choose>
            <xsl:when
                test="normalize-space()='' and count((ancestor::*[matches(name(),'h\d')][1]//text() intersect preceding::text())[normalize-space()]) and count((ancestor::*[matches(name(),'h\d')][1]//text() intersect following::text())[normalize-space()])">
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space(.)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- <bridgehead> is not allowed in nordic DTBook. Using p instead. -->
    <xsl:template match="html:p[f:types(.)='bridgehead']">
        <xsl:message select="'&lt;bridgehead&gt; is not allowed in nordic DTBook. Using p instead with a bridgehead class.'"/>
        <p>
            <xsl:call-template name="f:attlist.bridgehead"/>
            <xsl:apply-templates select="node()"/>
        </p>
    </xsl:template>

    <!-- <bridgehead> is not allowed in nordic DTBook. Using p instead with a bridgehead class. -->
    <xsl:template name="f:attlist.bridgehead">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="classes" select="'bridgehead'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="html:blockquote">
        <blockquote>
            <xsl:call-template name="f:attlist.blockquote"/>
            <xsl:apply-templates select="node()"/>
        </blockquote>
    </xsl:template>

    <xsl:template name="f:attlist.blockquote">
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@cite"/>
    </xsl:template>

    <xsl:template match="html:dl">
        <dl>
            <xsl:call-template name="f:attlist.dl"/>
            <xsl:apply-templates select="node()"/>
        </dl>
    </xsl:template>

    <xsl:template name="f:attlist.dl">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:dt">
        <dt>
            <xsl:call-template name="f:attlist.dt"/>
            <xsl:apply-templates select="node()"/>
        </dt>
    </xsl:template>

    <xsl:template name="f:attlist.dt">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:dd">
        <dd>
            <xsl:call-template name="f:attlist.dd"/>
            <xsl:apply-templates select="node()"/>
        </dd>
    </xsl:template>

    <xsl:template name="f:attlist.dd">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:ol | html:ul">
        <xsl:choose>
            <xsl:when test="f:types(.)=('rearnotes','footnotes') or html:li/f:types(.)=('rearnote','footnote')">
                <xsl:apply-templates select="node()"/>
            </xsl:when>
            <xsl:otherwise>
                <list>
                    <xsl:call-template name="f:attlist.list"/>
                    <xsl:apply-templates select="node()"/>
                </list>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="f:attlist.list">
        <!-- Only 'pl' is allowed in nordic DTBook, markers will be inlined. A generic script would set type to ul or ol (i.e. select="local-name()"). -->
        <xsl:attribute name="type" select="if (f:classes(.) = 'list-style-type-none') then 'pl' else local-name()"/>
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@start"/>
        <xsl:if test="@type">
            <xsl:attribute name="enum" select="@type"/>
        </xsl:if>
        <xsl:attribute name="depth" select="count(ancestor::html:li[not(f:types(.)=('rearnote','footnote'))])+1"/>
    </xsl:template>

    <xsl:template match="html:li">
        <li>
            <xsl:call-template name="f:attlist.li"/>
            <xsl:apply-templates select="node()"/>
        </li>
    </xsl:template>
    <xsl:template name="f:attlist.li">
        <xsl:call-template name="f:attrs"/>
        
        <!-- the value attribute is not allowed in DTBook
            
        <xsl:variable name="value" select="f:li-value(.)" as="xs:integer"/>
        <xsl:choose>
            <xsl:when test="exists(@value)">
                <xsl:attribute name="value" select="$value"/>
            </xsl:when>
            <xsl:when test="exists(preceding-sibling::html:li) and not($value = preceding-sibling::html:li[1]/f:li-value(.) + 1)">
                <xsl:attribute name="value" select="$value"/>
            </xsl:when>
        </xsl:choose>
        
        -->
    </xsl:template>

    <xsl:template match="html:span[f:classes(.)='lic']">
        <xsl:variable name="position" select="count(preceding-sibling::*) + 1"/>
        <xsl:variable name="children" select="node()"/>
        <lic>
            <xsl:call-template name="f:attlist.lic"/>
            <xsl:choose>
                <xsl:when test="parent::html:a">
                    <xsl:variable name="a">
                        <xsl:for-each select="parent::*">
                            <xsl:call-template name="f:a">
                                <xsl:with-param name="children" select="$children"/>
                            </xsl:call-template>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:for-each select="$a/node()">
                        <xsl:choose>
                            <xsl:when test="count(@* except @id) or ($position = 1 and @id)">
                                <xsl:copy>
                                    <xsl:copy-of select="@* except @id"/>
                                    <xsl:if test="$position = 1">
                                        <xsl:copy-of select="@id"/>
                                    </xsl:if>
                                    <xsl:copy-of select="node()"/>
                                </xsl:copy>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:copy-of select="node()"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="node()"/>
                </xsl:otherwise>
            </xsl:choose>
        </lic>
    </xsl:template>

    <xsl:template name="f:attlist.lic">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="'lic'" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template name="f:cellhvalign">
        <!--
            the @cellhalign and @cellvalign attributes could potentially be inferred from the CSS here,
            but it's probably not worth it so they are ignored for now.
        -->
    </xsl:template>

    <xsl:template match="html:table">
        <table>
            <xsl:call-template name="f:attlist.table"/>
            <xsl:for-each select="html:caption">
                <xsl:call-template name="f:caption.table"/>
            </xsl:for-each>
            <xsl:apply-templates select="html:colgroup"/>

            <xsl:apply-templates select="html:thead/html:tr"/>
            <xsl:apply-templates select="html:tbody/html:tr | html:tr"/>
            <xsl:apply-templates select="html:tfoot/html:tr"/>

            <!--<xsl:apply-templates select="html:thead"/>
            <xsl:apply-templates select="html:tfoot"/>
            <xsl:apply-templates select="html:tbody | html:tr"/>-->
        </table>
    </xsl:template>

    <xsl:template name="f:attlist.table">
        <xsl:call-template name="f:attrs">
            <xsl:with-param name="except-classes" select="for $class in (f:classes(.)) return if (starts-with($class,'table-rules') or starts-with($class,'table-frame-')) then $class else ()"
                tunnel="yes"/>
        </xsl:call-template>
        <xsl:if test="html:caption/html:p[f:classes(.)='table-summary']">
            <xsl:attribute name="summary" select="normalize-space(string-join(html:caption/html:p[f:classes(.)='table-summary']//text(),' '))"/>
        </xsl:if>
        <xsl:if test="count(f:classes(.)[matches(.,'^table-rules-')])">
            <xsl:attribute name="rules" select="replace(f:classes(.)[matches(.,'^table-rules-')][1],'^table-rules-','')"/>
        </xsl:if>
        <xsl:if test="count(f:classes(.)[matches(.,'^table-frame-')])">
            <xsl:attribute name="frame" select="replace(f:classes(.)[matches(.,'^table-frame-')][1],'^table-frame-','')"/>
        </xsl:if>
        <!--
            @cellspacing, @cellpadding and @width could potentially be inferred from the CSS,
            but it's probably not worth it so they are ignored for now
        -->
    </xsl:template>

    <xsl:template name="f:caption.table">
        <xsl:variable name="content" select="node()[not(self::html:p[f:classes(.)='table-summary'])]"/>
        <xsl:if test="$content">
            <caption>
                <xsl:call-template name="f:attlist.caption"/>
                <xsl:apply-templates select="$content"/>
            </caption>
        </xsl:if>
    </xsl:template>

    <xsl:template match="html:figcaption">
        <caption>
            <xsl:call-template name="f:attlist.caption"/>
            <xsl:apply-templates select="node()"/>
        </caption>
    </xsl:template>

    <xsl:template name="f:attlist.caption">
        <xsl:call-template name="f:attrs"/>
    </xsl:template>

    <xsl:template match="html:thead">
        <thead>
            <xsl:call-template name="f:attlist.thead"/>
            <xsl:apply-templates select="node()"/>
        </thead>
    </xsl:template>

    <xsl:template name="f:attlist.thead">
        <xsl:call-template name="f:attrs"/>
        <xsl:call-template name="f:cellhvalign"/>
    </xsl:template>

    <xsl:template match="html:tfoot">
        <tfoot>
            <xsl:call-template name="f:attlist.tfoot"/>
            <xsl:apply-templates select="node()"/>
        </tfoot>
    </xsl:template>

    <xsl:template name="f:attlist.tfoot">
        <xsl:call-template name="f:attrs"/>
        <xsl:call-template name="f:cellhvalign"/>
    </xsl:template>

    <xsl:template match="html:tbody">
        <tbody>
            <xsl:call-template name="f:attlist.tbody"/>
            <xsl:apply-templates select="node()"/>
        </tbody>
    </xsl:template>

    <xsl:template name="f:attlist.tbody">
        <xsl:call-template name="f:attrs"/>
        <xsl:call-template name="f:cellhvalign"/>
    </xsl:template>

    <!-- <colgroup> is not allowed in nordic DTBook. -->
    <xsl:template match="html:colgroup">
        <xsl:message select="'&lt;colgroup&gt; is not allowed in nordic DTBook.'"/>
        <!--<colgroup>
            <xsl:call-template name="f:attlist.colgroup"/>
            <xsl:apply-templates select="node()"/>
        </colgroup>-->
    </xsl:template>

    <xsl:template name="f:attlist.colgroup">
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@span"/>
        <xsl:call-template name="f:cellhvalign"/>
        <!--
            @width could potentially be inferred from the CSS,
            but it's probably not worth it so they are ignored for now
        -->
    </xsl:template>

    <!-- <col> is not allowed in nordic DTBook. -->
    <xsl:template match="html:col">
        <xsl:message select="'&lt;col&gt; is not allowed in nordic DTBook.'"/>
        <!--<col>
            <xsl:call-template name="f:attlist.col"/>
            <xsl:apply-templates select="node()"/>
        </col>-->
    </xsl:template>

    <xsl:template name="f:attlist.col">
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@span"/>
        <xsl:call-template name="f:cellhvalign"/>
        <!--
            @width could potentially be inferred from the CSS,
            but it's probably not worth it so they are ignored for now
        -->
    </xsl:template>

    <xsl:template match="html:tr">
        <xsl:choose>
            <xsl:when test="not(html:td//*[self::html:span[f:types(.)='pagebreak']])">
                <tr>
                    <xsl:call-template name="f:attlist.tr"/>
                    <xsl:apply-templates select="node()"/>
                </tr>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="content" select="html:td//*[self::html:span[f:types(.)='pagebreak']]"/>
                <xsl:for-each select="$content">
                    <pagenum>
                        <xsl:call-template name="f:attlist.pagenum"/>
                        <xsl:value-of select="@title"/>
                    </pagenum>
                </xsl:for-each>
                <tr>
                    <xsl:call-template name="f:attlist.tr"/>
                    <xsl:apply-templates select="node()"/>
                </tr>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="f:attlist.tr">
        <xsl:call-template name="f:attrs"/>
        <xsl:call-template name="f:cellhvalign"/>
        <!--
            @width could potentially be inferred from the CSS,
            but it's probably not worth it so they are ignored for now
        -->
    </xsl:template>

    <xsl:template match="html:th">
        <th>
            <xsl:call-template name="f:attlist.th"/>
            <xsl:apply-templates select="node()"/>
        </th>
    </xsl:template>

    <xsl:template name="f:attlist.th">
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@headers|@scope|@rowspan|@colspan"/>
        <xsl:call-template name="f:cellhvalign"/>
    </xsl:template>

    <xsl:template match="html:td">
        <td>
            <xsl:call-template name="f:attlist.td"/>
            <xsl:apply-templates select="node()"/>
        </td>
    </xsl:template>

    <xsl:template name="f:attlist.td">
        <xsl:call-template name="f:attrs"/>
        <xsl:copy-of select="@headers|@scope|@rowspan|@colspan"/>
        <xsl:call-template name="f:cellhvalign"/>
    </xsl:template>

    <xsl:template name="f:copy-preceding-comments">
        <xsl:variable name="this" select="."/>
        <xsl:apply-templates select="preceding-sibling::comment()[not($this/preceding-sibling::*) or preceding-sibling::*[1] is $this/preceding-sibling::*[1]]"/>
    </xsl:template>

    <xsl:function name="f:types" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type,'\s+')"/>
    </xsl:function>

    <xsl:function name="f:classes" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@class,'\s+')"/>
    </xsl:function>

    <xsl:function name="f:level" as="xs:integer">
        <xsl:param name="element" as="element()"/>
        <xsl:variable name="level" select="($element/ancestor-or-self::html:*[self::html:section or self::html:article or self::html:aside or self::html:nav or self::html:body])[last()]"/>
        <xsl:variable name="level-depth" select="count($level/ancestor-or-self::*[self::html:section or self::html:article or self::html:aside or self::html:nav])"/>
        <xsl:variable name="preceding-headings-in-level" select="$element/(ancestor-or-self::* intersect $level/*)/(. | preceding-sibling::*)[self::html:h1 or self::html:h2 or self::html:h3 or self::html:h4 or self::html:h5 or self::html:h6]"/>
        
        <xsl:choose>
            <xsl:when test="count($preceding-headings-in-level) le 1">
                <!-- level based only on sectioning depth -->
                <xsl:value-of select="min(($level-depth, 6))"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- level should be one deeper than the sectioning depth -->
                <xsl:value-of select="min(($level-depth + 1, 6))"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="f:level-nodes" as="node()*">
        <xsl:param name="level" as="element()"/>
        <xsl:variable name="level-levels"
            select="$level//html:*[(self::html:section or self::html:article or self::html:aside or self::html:nav or self::html:body) and ((ancestor::html:*[self::html:section or self::html:article or self::html:aside or self::html:nav or self::html:body])[last()] intersect $level)]"/>
        <xsl:variable name="level-nodes" select="$level//node()[not(ancestor-or-self::* intersect $level-levels)]"/>
        <xsl:sequence select="$level-nodes"/>
    </xsl:function>

    <xsl:function name="f:generate-pretty-id" as="xs:string">
        <xsl:param name="element" as="element()"/>
        <xsl:param name="all-ids" as="xs:string*"/>
        <xsl:variable name="id">
            <xsl:choose>
                <xsl:when test="$element[self::html:blockquote or self::html:q]">
                    <xsl:sequence select="concat('quote_',count($element/(ancestor::*|preceding::*)[self::html:blockquote or self::html:q])+1)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="element-name" select="local-name($element)"/>
                    <xsl:sequence select="concat($element-name,'_',count($element/(ancestor::*|preceding::*)[local-name()=$element-name])+1)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:sequence select="if ($all-ids=$id) then generate-id($element) else $id"/>
    </xsl:function>

    <xsl:function name="f:li-value" as="xs:integer">
        <xsl:param name="li" as="element()"/>
        <xsl:choose>
            <xsl:when test="not($li)">
                <xsl:value-of select="1"/>
            </xsl:when>
            <xsl:when test="$li/@value">
                <xsl:value-of select="$li/@value"/>
            </xsl:when>
            <xsl:when test="not($li/preceding-sibling::*)">
                <xsl:value-of select="if ($li/parent::*/@start) then $li/parent::*/@start else if ($li/parent::*/@reversed) then count($li/parent::*/*) else 1"/>
            </xsl:when>
            <xsl:when test="$li/parent::*/@reversed">
                <xsl:value-of
                    select="if ($li/preceding-sibling::*[@value]) then f:li-value(($li/preceding-sibling::*[@value])[last()]) - 1 - count($li/preceding-sibling::* intersect ($li/preceding-sibling::*[@value])[last()]/following-sibling::*) else ($li/parent::*/@start/number(.), count($li/parent::*/*))[1] - count($li/preceding-sibling::*)"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of
                    select="if ($li/preceding-sibling::*[@value]) then f:li-value(($li/preceding-sibling::*[@value])[last()]) + 1 + count($li/preceding-sibling::* intersect ($li/preceding-sibling::*[@value])[last()]/following-sibling::*) else ($li/parent::*/@start/number(.), 1)[1] + count($li/preceding-sibling::*)"
                />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="f:numeric-decimal-to-alpha">
        <!-- TODO: move this to numeral-conversion.xsl in DP2 common-utils -->
        <xsl:param name="decimal" as="xs:integer"/>
        <xsl:value-of select="string-join(f:numeric-decimal-to-alpha-part($decimal,()),'')"/>
    </xsl:function>

    <xsl:function name="f:numeric-decimal-to-alpha-part">
        <xsl:param name="remainder" as="xs:integer"/>
        <xsl:param name="result" as="xs:string*"/>
        <xsl:choose>
            <xsl:when test="$remainder &lt;= 0">
                <xsl:sequence select="$result"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="f:numeric-decimal-to-alpha-part(xs:integer(floor($remainder div 26)), (codepoints-to-string(($remainder mod 26) + 96), $result))"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="f:is-inline" as="xs:boolean">
        <xsl:param name="element" as="node()"/>
        <xsl:sequence select="$element[self::text()] or $element[self::* and local-name() = ('a','abbr','bdo','br','code','dfn','em','img','kbd','q','samp','span','strong','sub','sup')]"/>
    </xsl:function>

</xsl:stylesheet>
