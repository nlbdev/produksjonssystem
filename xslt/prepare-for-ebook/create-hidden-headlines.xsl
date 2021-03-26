<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns:epub="http://www.idpf.org/2007/ops"
                exclude-result-prefixes="#all"
                xmlns:f="#"
                version="2.0">
    
    <xsl:param name="cover-headlines" select="'from-type'"/> <!-- omit / from-type / from-text -->
    <xsl:param name="frontmatter-headlines" select="'from-type'"/> <!-- omit / from-type / from-text -->
    <xsl:param name="bodymatter-headlines" select="'from-text'"/> <!-- omit / from-type / from-text -->
    <xsl:param name="backmatter-headlines" select="'from-type'"/> <!-- omit / from-type / from-text -->
    <xsl:param name="always-from-text" select="'z3998:poem'"/> <!-- comma separated list of types that should always be based on the text -->
    
    <xsl:variable name="alwaysFromText" select="tokenize($always-from-text, '\s*,\s*')"/>  <!-- list version of always-from-text -->
    
    <xsl:output indent="no" method="xhtml" include-content-type="no"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- generate-id may return IDs that are already present in the document. We'll prepend it with 'generated-headline-' which should avoid conflicting IDs -->
    <xsl:function name="f:generate-id" as="xs:string">
        <xsl:param name="element" as="element()"/>
        
        <xsl:value-of select="concat('generated-headline-', $element/generate-id())"/>
    </xsl:function>
    
    <xsl:template match="h1[not(@id)] | h2[not(@id)] | h3[not(@id)] | h4[not(@id)] | h5[not(@id)] | h6[not(@id)]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="id" select="f:generate-id(.)"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[not(exists(h1 | h2 | h3 | h4 | h5 | h6))]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            
            <xsl:variable name="level" select="count(ancestor-or-self::section)"/>
            <xsl:variable name="hx" select="concat('h', min((6, $level)))" as="xs:string"/>
            <xsl:variable name="chapter-headline" select="f:chapter-headline(.)" as="xs:string"/>

            <xsl:if test="$chapter-headline">
                <xsl:element name="{$hx}" namespace="http://www.w3.org/1999/xhtml">
                    <xsl:attribute name="id" select="f:generate-id(.)"/>
                    <xsl:attribute name="class" select="'generated-headline hidden-headline'"/>
                    <xsl:value-of select="$chapter-headline"/>
                </xsl:element>
            </xsl:if>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="f:chapter-headline" as="xs:string">
        <xsl:param name="section" as="element()"/>
        
        <xsl:variable name="matter" select="for $type in ($section/ancestor-or-self::section[last()]/f:types(.)) return (if ($type = ('cover', 'frontmatter', 'bodymatter', 'backmatter')) then $type else ())" as="xs:string*"/>
        <xsl:variable name="matter" select="($matter, 'bodymatter')[1]" as="xs:string"/>

        <xsl:choose>
            <xsl:when test="($matter = $alwaysFromText) or ($section/f:types(.) = $alwaysFromText)">
                <xsl:variable name="first-text"  select="f:chapter-first-text($section)"/>
                <xsl:value-of select="if ($first-text != '') then $first-text else f:chapter-translation($matter, $section)"/>
            </xsl:when>
            
            <xsl:when test="$matter = 'cover'">
                <xsl:choose>
                    <xsl:when test="$cover-headlines = 'from-type'">
                        <xsl:value-of select="f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:when test="$cover-headlines = 'from-text'">
                        <xsl:variable name="first-text"  select="f:chapter-first-text($section)"/>
                        <xsl:value-of select="if ($first-text != '') then $first-text else f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="''"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            
            <xsl:when test="$matter = 'frontmatter'">
                <xsl:choose>
                    <xsl:when test="$frontmatter-headlines = 'from-type'">
                        <xsl:value-of select="f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:when test="$frontmatter-headlines = 'from-text'">
                        <xsl:variable name="first-text"  select="f:chapter-first-text($section)"/>
                        <xsl:value-of select="if ($first-text != '') then $first-text else f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="''"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            
            <xsl:when test="$matter = 'bodymatter'">
                <xsl:choose>
                    <xsl:when test="$bodymatter-headlines = 'from-type'">
                        <xsl:value-of select="f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:when test="$bodymatter-headlines = 'from-text'">
                        <xsl:variable name="first-text"  select="f:chapter-first-text($section)"/>
                        <xsl:value-of select="if ($first-text != '') then $first-text else f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="''"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            
            <xsl:when test="$matter = 'backmatter'">
                <xsl:choose>
                    <xsl:when test="$backmatter-headlines = 'from-type'">
                        <xsl:value-of select="f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:when test="$backmatter-headlines = 'from-text'">
                        <xsl:variable name="first-text"  select="f:chapter-first-text($section)"/>
                        <xsl:value-of select="if ($first-text != '') then $first-text else f:chapter-translation($matter, $section)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="''"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:value-of select="''"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:types" as="xs:string*">
        <xsl:param name="context" as="element()"/>
        <xsl:sequence select="$context/tokenize(@epub:type, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:classes" as="xs:string*">
        <xsl:param name="context" as="element()"/>
        <xsl:sequence select="$context/tokenize(@class, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:chapter-first-text">
        <xsl:param name="section" as="element()"/>
        
        <xsl:variable name="text" select="string-join((($section//text() except $section//section//text())[normalize-space()])[position() le 10], ' ')" as="xs:string"/>
        <xsl:variable name="text" select="normalize-space($text)" as="xs:string"/>
        <xsl:variable name="text" select="string(replace($text, '^(.*?[a-zA-ZæøåÆØÅ].*?)\..*', '$1'))" as="xs:string"/>
        
        <xsl:choose>
            <xsl:when test="$text = ''">
                <xsl:message>
                    <xsl:text>
```
</xsl:text>
                    <xsl:copy-of select="$section"/>
                    <xsl:text>
```
</xsl:text>
                </xsl:message>
                <xsl:message select="concat(
                    'No usable text content for headline available. Falling back to type-based headline. At: ',
                    '/', string-join((for $e in ($section/ancestor-or-self::*) return concat('*[', count($e/preceding-sibling::*) + 1, ']')), '/'),
                    if ($section/@id) then concat(' (', $section/name(), '[@id=''', $section/@id, '''])') else '')"/>
            </xsl:when>
            <xsl:when test="count(tokenize($text, ' ')) le 3">
                <xsl:value-of select="string-join($text, ' ')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat(string-join(tokenize($text, ' ')[position() le 3], ' '), '...')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:chapter-translation">
        <xsl:param name="matter" as="xs:string"/>
        <xsl:param name="section" as="element()"/>
        
        <xsl:variable name="language" select="($section/ancestor-or-self::*/@xml:lang)[last()]" as="xs:string"/>
        <xsl:variable name="language" select="if ($language = 'no') then 'nn' else $language"/>  <!-- pick a language -->
        
        <xsl:variable name="document-divisions" as="element()*">
            <type name="cover">
                <en>Cover</en>
                <nb>Omslag</nb>
                <nn>Omslag</nn>
            </type>
            <type name="frontmatter">
                <en>Frontmatter</en>
                <nb>Frontmaterie</nb>
                <nn>Frontmaterie</nn>
            </type>
            <type name="bodymatter">
                <en>Chapter</en>
                <nb>Kapittel</nb>
                <nn>Kapittel</nn>
            </type>
            <type name="backmatter">
                <en>Backmatter</en>
                <nb>Sluttmaterie</nb>
                <nn>Sluttmaterie</nn>
            </type>
            <type name="part">
                <en>Part</en>
                <nb>Del</nb>
                <nn>Del</nn>
            </type>
        </xsl:variable>
        
        <xsl:variable name="document-sections" as="element()*">
            <class name="frontcover">
                <en>Front cover</en>
                <nb>Forside</nb>
                <nn>Framside</nn>
            </class>
            <class name="rearcover">
                <en>Back cover</en>
                <nb>Bakside</nb>
                <nn>Bakside</nn>
            </class>
            <class name="leftflap">
                <en>Left flap</en>
                <nb>Venstre innbrett</nb>
                <nn>Venstre innbrett</nn>
            </class>
            <class name="rightflap">
                <en>Right flap</en>
                <nb>Høyre innbrett</nb>
                <nn>Høgre innbrett</nn>
            </class>
            <type name="volume">
                <en>Volume</en>
                <nb>Bind</nb>
                <nn>Bind</nn>
            </type>
            <type name="part">
                <en>Part</en>
                <nb>Del</nb>
                <nn>Del</nn>
            </type>
            <type name="chapter">
                <en>Chapter</en>
                <nb>Kapittel</nb>
                <nn>Kapittel</nn>
            </type>
            <type name="subchapter">
                <en>Subchapter</en>
                <nb>Underkapittel</nb>
                <nn>Underkapittel</nn>
            </type>
            <type name="division">
                <en>Division</en>
                <nb>Del</nb>
                <nn>Del</nn>
            </type>
            <type name="z3998:section">
                <en>Section</en>
                <nb/>
                <nn/>
            </type>
            <type name="z3998:subsection">
                <en>Subsection</en>
                <nb/>
                <nn/>
            </type>
            <type name="abstract">
                <en>Abstract</en>
                <nb>Sammendrag</nb>
                <nn>Samandrag</nn>
            </type>
            <type name="foreword">
                <en>Foreword</en>
                <nb>Forord</nb>
                <nn>Forord</nn>
            </type>
            <type name="preface">
                <en>Preface</en>
                <nb>Innledning</nb>
                <nn>Innleiing</nn>
            </type>
            <type name="prologue">
                <en>Prologue</en>
                <nb>Prolog</nb>
                <nn>Prolog</nn>
            </type>
            <type name="introduction">
                <en>Introduction</en>
                <nb>Innledning</nb>
                <nn>Innleiing</nn>
            </type>
            <type name="preamble">
                <en>Preamble</en>
                <nb>Innledning</nb>
                <nn>Innleiing</nn>
            </type>
            <type name="conclusion">
                <en>Conclusion</en>
                <nb/>
                <nn>Avslutning/Konklusjon</nn>
            </type>
            <type name="epilogue">
                <en>Epilogue</en>
                <nb>Epilog</nb>
                <nn>Epilog</nn>
            </type>
            <type name="afterword">
                <en>Afterword</en>
                <nb>Etterord </nb>
                <nn>Etterord</nn>
            </type>
            <type name="epigraph">
                <en>Epigraph</en>
                <nb>Innskrift</nb>
                <nn>Innskrift</nn>
            </type>
            <type name="toc">
                <en>Table of contents</en>
                <nb>Innhold</nb>
                <nn>Innhald</nn>
            </type>
            <type name="toc-brief">
                <en>Abridged table of contents</en>
                <nb>Forkortet innholdsfortegnelse</nb>
                <nn>Kort innhaldsfortegnelse</nn>
            </type>
            <type name="landmarks">
                <en>Landmarks</en>
                <nb/>
                <nn/>
            </type>
            <type name="loa">
                <en>List of audio clips</en>
                <nb>Lydklipp</nb>
                <nn>Lydklipp</nn>
            </type>
            <type name="loi">
                <en>List of illustrations</en>
                <nb>Illustrasjoner</nb>
                <nn>Illustrasjonar</nn>
            </type>
            <type name="lot">
                <en>List of tables</en>
                <nb>Tabeller</nb>
                <nn>Tabellar</nn>
            </type>
            <type name="lov">
                <en>List of video clips</en>
                <nb>Videoer</nb>
                <nn>Videoar</nn>
            </type>
            <type name="appendix">
                <en>Appendix</en>
                <nb>Vedlegg</nb>
                <nn>Vedlegg</nn>
            </type>
            <type name="colophon">
                <en>Colophon</en>
                <nb>Kolofon</nb>
                <nn>Kolofon</nn>
            </type>
            <type name="credits">
                <en>Credits</en>
                <nb>Bidragsytere</nb>
                <nn>Bidragsytere</nn>
            </type>
            <type name="keywords">
                <en>Keywords</en>
                <nb>Søkeord</nb>
                <nn>Søkjeord</nn>
            </type>
            <type name="z3998:discography">
                <en>Discography</en>
                <nb/>
                <nn/>
            </type>
            <type name="z3998:filmography">
                <en>Filmography</en>
                <nb/>
                <nn/>
            </type>
            <type name="index">
                <en>Index</en>
                <nb>Innhold</nb>
                <nn>Innhald</nn>
            </type>
            <type name="index-headnotes">
                <en>Headnotes</en>
                <nb>Innhold</nb>
                <nn>Innhald</nn>
            </type>
            <type name="index-legend">
                <en>Legend</en>
                <nb>Symbolfolklaring</nb>
                <nn>Symbolfolklaring</nn>
            </type>
            <type name="index-group">
                <en>Group</en>
                <nb/>
                <nn/>
            </type>
            <type name="glossary">
                <en>Glossary</en>
                <nb>Ordliste</nb>
                <nn>Ordliste</nn>
            </type>
            <type name="dictionary">
                <en>Dictionary</en>
                <nb>Ordliste</nb>
                <nn>Ordliste</nn>
            </type>
            <type name="bibliography">
                <en>Bibliography</en>
                <nb>Bibliografi</nb>
                <nn>Bibliografi</nn>
            </type>
            <type name="titlepage">
                <en>Title page</en>
                <nb>Tittelside</nb>
                <nn>Tittelside</nn>
            </type>
            <type name="halftitlepage">
                <en>Half title page</en>
                <nb>Tittel</nb>
                <nn>Tittel</nn>
            </type>
            <type name="copyright-page">
                <en>Copyright page</en>
                <nb>Opphavsrett</nb>
                <nn>Opphavsrett</nn>
            </type>
            <type name="seriespage">
                <en>Series page</en>
                <nb>Andre bøker i serien</nb>
                <nn>Andre bøker i serien</nn>
            </type>
            <type name="acknowledgments">
                <en>Acknowledgments</en>
                <nb>Takk til:</nb>
                <nn>Takk til:</nn>
            </type>
            <type name="imprint">
                <en>Imprint</en>
                <nb>Imprint</nb>
                <nn>Imprint</nn>
            </type>
            <type name="imprimatur">
                <en>Imprimatur</en>
                <nb>Imprimatur</nb>
                <nn>Imprimatur</nn>
            </type>
            <type name="contributors">
                <en>Contributors</en>
                <nb>Bidragsytere</nb>
                <nn>Bidragsytere</nn>
            </type>
            <type name="other-credits">
                <en>Other credits</en>
                <nb>Andre bidragsytere</nb>
                <nn>Andre bidragsytere</nn>
            </type>
            <type name="errata">
                <en>Errata</en>
                <nb/>
                <nn/>
            </type>
            <type name="dedication">
                <en>Dedication</en>
                <nb>Dedikasjon</nb>
                <nn>Dedikasjon</nn>
            </type>
            <type name="revision-history">
                <en>Revision history</en>
                <nb>Revidert</nb>
                <nn>Revidert</nn>
            </type>
            <type name="z3998:published-works">
                <en>Published works</en>
                <nb>Tidlegere utgitt</nb>
                <nn>Tidlegare utgivingar</nn>
            </type>
            <type name="z3998:publisher-address">
                <en>Publisher address</en>
                <nb>Adresse</nb>
                <nn>Adresse</nn>
            </type>
            <type name="z3998:editorial-note">
                <en>Editorial note</en>
                <nb/>
                <nn/>
            </type>
            <type name="z3998:grant-acknowledgment">
                <en>Grant acknowledgment</en>
                <nb/>
                <nn/>
            </type>
            <type name="z3998:biographical-note">
                <en>Biographical note</en>
                <nb>Biblografi</nb>
                <nn>Biblografi</nn>
            </type>
            <type name="z3998:translator-note">
                <en>Translator note</en>
                <nb>Oversetterns kommentar</nb>
                <nn>Omsetjarens kommentar</nn>
            </type>
            <type name="z3998:promotional-copy">
                <en>Promotional copy</en>
                <nb/>
                <nn/>
            </type>
            <type name="case-study">
                <en>Case study</en>
                <nb>Eksempelstudie</nb>
                <nn>Eksempelstudie</nn>
            </type>
            <type name="notice">
                <en>Notice</en>
                <nb>Notis</nb>
                <nn>Anførsel</nn>
            </type>
            <type name="answers">
                <en>Answers</en>
                <nb>Svar</nb>
                <nn>Svar</nn>
            </type>
            <type name="assessment">
                <en>Assessment</en>
                <nb>Vurdering</nb>
                <nn>Vurdering</nn>
            </type>
            <type name="assessments">
                <en>Assessments</en>
                <nb>Vurderinger</nb>
                <nn>Vurderingar</nn>
            </type>
            <type name="qna">
                <en>Questions and answers</en>
                <nb>Spørsmål og svar</nb>
                <nn>Spørsmål og svar</nn>
            </type>
            <type name="practices">
                <en>Practices</en>
                <nb>Øvinger</nb>
                <nn>Øvingar</nn>
            </type>
            <type name="footnotes">
                <en>Footnotes</en>
                <nb>Noter</nb>
                <nn>Noter</nn>
            </type>
            <type name="rearnotes">
                <en>Rearnotes</en>
                <nb>Noter</nb>
                <nn>Noter</nn>
            </type>
            <type name="endnotes">
                <en>Endnotes</en>
                <nb>Noteapparat</nb>
                <nn>Noteapparat</nn>
            </type>
            <type name="page-list">
                <en>Page list</en>
                <nb/>
                <nn/>
            </type>
            <type name="z3998:poem">
                <en>Poem</en>
                <nb>Dikt</nb>
                <nn>Dikt</nn>
            </type>
        </xsl:variable>
        
        <xsl:variable name="section-title" select="$document-sections[local-name() = 'type' and @name = f:types($section)][1]/*[local-name() = $language]/text()" as="xs:string?"/>
        <xsl:variable name="section-title" select="if ($section-title) then $section-title else $document-sections[local-name() = 'class' and @name = f:classes($section)][1]/*[local-name() = $language]/text()" as="xs:string?"/>
        
        <xsl:variable name="division-title" select="(
            $document-divisions[@name = $matter]/*[local-name() = $language]/text(),
            $document-divisions[@name = $matter]/*:nn/text(),
            $document-divisions[@name = 'bodymatter']/*[local-name() = $language]/text(),
            $document-divisions[@name = 'bodymatter']/*:nn/text()
        )[1]" as="xs:string?"/>
        
        <xsl:value-of select="if ($section-title) then $section-title else if ($division-title) then $division-title else ''"/>
        
    </xsl:function>
    
</xsl:stylesheet>