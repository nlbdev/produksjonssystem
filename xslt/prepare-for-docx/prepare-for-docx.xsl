<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:f="#" xpath-default-namespace="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">
 <xsl:output method="xhtml" indent="no" include-content-type="no"/>
   <xsl:template match="@* | node()" mode="#all">
      <xsl:copy copy-namespaces="no" exclude-result-prefixes="#all">
         <xsl:apply-templates select="@* | node()" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="comment()" priority="2" />
   <xsl:template match="span[@class = 'answer']">
      <xsl:text>....</xsl:text>
   </xsl:template>
   <xsl:template match="span[@class = 'answer_1']">
      <xsl:text>_</xsl:text>
   </xsl:template>
   <xsl:template match="div[@class='list-enumeration-1']">
      <p>
         <xsl:for-each select="./p/span">
            <xsl:apply-templates select="."/>
            <xsl:if test="not(position() = last())">
               <xsl:choose>
                  <xsl:when test="not(matches(.,'\.$'))">
                     <xsl:text>, </xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:text> </xsl:text>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:if>
         </xsl:for-each>
      </p>
   </xsl:template>
   <xsl:template match="span[@class='lic']">
      <xsl:apply-templates />
      <xsl:if test="exists(following-sibling::node()[1][matches(name(), 'span')])">
         <xsl:text> </xsl:text>
      </xsl:if>
   </xsl:template>
   <xsl:template match="th[. =''] | thead//td[. =''] | td[. ='' and not(exists(ancestor::section[matches(@class, 'oppgaver1|task')]))]">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:text>--</xsl:text>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="td[. ='' and exists(ancestor::section[matches(@class, '^(oppgaver1|task)$')]) and not(exists(ancestor::thead))]">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:text>....</xsl:text>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="li/ol[not(exists(preceding-sibling::*) or preceding-sibling::node()[matches(., '[^\s]')])] | li/ul[not(exists(preceding-sibling::*) or preceding-sibling::node()[matches(., '[^\s]')])]">
      <span class="dummyToIncludeNumbering">STATPED_DUMMYTEXT_LI_OL</span>
      <xsl:next-match />
   </xsl:template>
   <xsl:template match="*[matches(name(), 'h[1-6]') and not(ancestor::section[f:types(.) = 'toc'] or ancestor::aside[f:classes(.) = 'glossary'])]">
      <!-- no extra p before if preceding-sibling[last()] is: page-nr or after another hx, or if hx contains pagenr -->
      <xsl:if test="not(preceding-sibling::*[position() = last()][name() ='div' or name() = 'span'][@class='page-normal'] or preceding-sibling::*[1][matches(name(), '^h[1-6]$')] or ((count(preceding-sibling::*)=0 and ../preceding-sibling::*[1][matches(name(), '^h[1-6]$')])) or child::span[f:types(.) = 'pagebreak'])">
      <!-- <xsl:if test="not(preceding-sibling::*[position() = last()][name() ='div' or name() = 'span'][@class='page-normal'] or preceding-sibling::*[1][matches(name(), '^h[1-6]$')] or ((count(preceding-sibling::*)=0 and ../preceding-sibling::*[1][matches(name(), '^h[1-6]$')])))"> -->
         <p/>
      </xsl:if>
      <xsl:copy exclude-result-prefixes="#all">
         <xsl:apply-templates select="@*"/>
         <xsl:text>xxx</xsl:text><xsl:value-of select="substring(name(),2,1)"/><xsl:text> </xsl:text>
         <xsl:apply-templates select="node()"/>
      </xsl:copy>
   </xsl:template>


    <xsl:function name="f:movePageTopLevel">
        <xsl:param name="element" as="element()"/>
        <xsl:variable name="movePageTopLevel" as="xs:boolean" select="not($element/ancestor::*[matches(name(), 'h[1-6]|table|th|td|p|li') or $element/ancestor::section[f:types(.)='toc']/ol[@class='list-type-none']])" />
        <xsl:value-of select="$movePageTopLevel" />
    </xsl:function>
    <xsl:function name="f:movePageBefore">
        <xsl:param name="element" as="element()"/>
        <xsl:variable name="movePageBefore" as="xs:boolean" select="matches($element/name(), 'h[1-6]|table|th|td') or exists($element/ancestor::section[f:types(.)='toc']/ol[@class='list-type-none'])" />
        <xsl:value-of select="$movePageBefore" />
    </xsl:function>
    <xsl:template match="*[f:movePageBefore(.)=true() and (.//span[@epub:type = 'pagebreak'] or .//div[@epub:type = 'pagebreak']) and f:movePageTopLevel(.)=true()]" priority="2">
        <xsl:for-each select=".//(./span | ./div)[@epub:type = 'pagebreak']">
            <xsl:call-template name="create-pagebreak">
               <xsl:with-param name="element" select="." />
            </xsl:call-template>
        </xsl:for-each>
        <xsl:next-match />
    </xsl:template>
    <xsl:template name="create-pagebreak">
        <xsl:param name="element" as="element()"/>
        <xsl:variable name="page-number" as="xs:integer" select="if (@title) then @title else text()"/>
        <xsl:variable name="startFrom" as="xs:integer" select="if (//meta[@name='startPagenumberingFrom']/@content) then //meta[@name='startPagenumberingFrom']/@content else 0" />
        <xsl:if test="$page-number ge $startFrom">
            <!-- Last page in book -->
            <xsl:variable name="max-page-number" select="(//div | //span)[f:types(.) = 'pagebreak'][last()]/(if (@title) then @title else text())"/>
            <!-- Last page in section -->
            <!-- <xsl:variable name="max-page-number" select="($element/ancestor::section//div | $element/ancestor::section//span)[f:types(.) = 'pagebreak'][last()]/(if (@title) then @title else text())"/> -->
            <xsl:variable name="to-page" select="$max-page-number"/>
            <xsl:if test="not(exists(ancestor::li/p | ancestor::figcaption/p | ancestor::figure[f:classes(.) = 'image']/aside/p | ancestor::caption/p))">
               <p/>
            </xsl:if>
            <div epub:type="pagebreak">
               <xsl:apply-templates select="@*"/>
               <xsl:attribute name="title" select="$page-number"/>
               <xsl:value-of select="concat('--- ', $page-number, ' til ', $to-page)"/>
            </div>
        </xsl:if>
    </xsl:template>
    <xsl:template match="div[f:types(.) = 'pagebreak' and f:movePageBefore(parent::*)=false() and f:movePageTopLevel(parent::*)=true() and not(ancestor::li)] | span[f:types(.) = 'pagebreak' and f:movePageBefore(parent::*)=false() and f:movePageTopLevel(parent::*)=true() and not(ancestor::li)]">
    <!-- <xsl:template match="(div | span)[f:types(.) = 'pagebreak' and f:movePageBefore(parent::*)=false() and f:movePageTopLevel(parent::*)=true() and not(ancestor::li)]"> -->
        <xsl:call-template name="create-pagebreak">
            <xsl:with-param name="element" select="." />
         </xsl:call-template>
    </xsl:template>
   <xsl:template match="p[f:movePageTopLevel(.)=true()]" priority="2">
   <!-- <xsl:template match="p[f:movePageBefore(.)=false()]" priority="2"> -->
      <xsl:next-match/>
      <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
         <xsl:call-template name="create-pagebreak">
            <xsl:with-param name="element" select="." />
         </xsl:call-template>
      </xsl:for-each>
   </xsl:template>
   <xsl:template match="figcaption/p[f:movePageBefore(.)=false()] | figure[f:classes(.) = 'image']/aside/p[f:movePageBefore(.)=false()] | caption/p[f:movePageBefore(.)=false()]" priority="3">
      <xsl:apply-templates/>
      <xsl:if test="position() != last() and not(exists(following-sibling::*[1][name() = 'ol' or name() = 'ul' or name() = 'table']))">
         <br/>         
      </xsl:if>
      <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
         <xsl:call-template name="create-pagebreak">
            <xsl:with-param name="element" select="." />
         </xsl:call-template>
      </xsl:for-each>
   </xsl:template>
   <xsl:template match="li[f:movePageBefore(.)=false() and .//span[@epub:type = 'pagebreak'] and not(exists(.//li//span[@epub:type = 'pagebreak']))]">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()"/>
         <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
            <xsl:call-template name="create-pagebreak">
               <xsl:with-param name="element" select="." />
            </xsl:call-template>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="aside[f:classes(.) = 'sidebar'] | div[f:classes(.) = 'linegroup'] | div[f:classes(.) = 'ramme'] | div[f:classes(.) = 'generisk-ramme']">
      <p/>
      <xsl:next-match/>
   </xsl:template>
   <xsl:template match="aside[f:classes(.) = 'glossary']/*[matches(name(), 'h[1-6]')]">
      <p>
         <xsl:text>_</xsl:text><xsl:apply-templates/><xsl:text>_</xsl:text>
      </p>
   </xsl:template>
   <xsl:template match="div[f:classes(.) = 'ramdoc'] | aside[f:classes(.) = 'ramdoc']">
      <p/>
      <xsl:copy>
         <p>
            <span xml:lang="no" lang="no">Ramme:</span>
         </p>
         <xsl:apply-templates select="node()"/>
      </xsl:copy>
   </xsl:template>
 
   <xsl:function name="f:imgAlt">
      <xsl:param name="element" as="element()"/>
      <xsl:choose>
         <xsl:when test="$element/@alt='photo'">
            <xsl:text>foto</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='illustration'">
            <xsl:text>illustrasjon</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='figure'">
            <xsl:text>figur</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='symbol'">
            <xsl:text>symbol</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='map'">
            <xsl:text>kart</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='drawing'">
            <xsl:text>tegning</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='comic'">
            <xsl:text>tegneserie</xsl:text>
         </xsl:when>
         <xsl:when test="$element/@alt='logo'">
            <xsl:text>logo</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$element/@alt" />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:template match="img">
      <xsl:text>[</xsl:text>
      <xsl:value-of select="f:imgAlt(.)"/>
      <xsl:text>]</xsl:text>
   </xsl:template>
   <xsl:template match="figure[f:classes(.) = 'image-series']">
      <xsl:apply-templates/>
   </xsl:template>
   <xsl:template match="figure[f:classes(.) = 'image']">
      <p/>
      <p>
         <xsl:attribute name="lang">no</xsl:attribute>
         <xsl:attribute name="xml:lang">no</xsl:attribute>
         <xsl:text>Bilde: </xsl:text>
         <xsl:value-of select="f:imgAlt(./img)"/>
      </p>
      <xsl:apply-templates select="./aside"/>
      <xsl:apply-templates select="./figcaption"/>
      <p/>
   </xsl:template>
   <xsl:template match="figure[f:classes(.) = 'image']/aside">
      <xsl:if test="not(normalize-space(.) = '¤' or normalize-space(.) = '*')">
         <p>
            <xsl:attribute name="lang">no</xsl:attribute>
            <xsl:attribute name="xml:lang">no</xsl:attribute>
            <xsl:text>Forklaring: </xsl:text>
            <xsl:apply-templates select="node()"/>
         </p>
      </xsl:if>
   </xsl:template>
   <xsl:template match="figcaption">
      <p>
         <xsl:attribute name="lang">no</xsl:attribute>
         <xsl:attribute name="xml:lang">no</xsl:attribute>
         <xsl:text>Bildetekst: </xsl:text>
         <xsl:apply-templates/>
      </p>
   </xsl:template>
   <xsl:template match="figure[f:classes(.) = 'image-series']/figcaption" priority="2">
      <p/>
      <p>
         <xsl:text>Bildeserie: </xsl:text>
         <xsl:apply-templates/>
      </p>
   </xsl:template>
 
   <xsl:template match="ol[parent::section[f:types(.) = 'toc']]" priority="10">
      <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
         <xsl:call-template name="create-pagebreak"/>
      </xsl:for-each>
      <!-- xsl:apply-templates select=".//span[@class='page-normal']" / -->
      <xsl:copy exclude-result-prefixes="#all">
         <xsl:apply-templates select="@*"/>
         <li>
            <span xml:lang="no" lang="no">xxx1</span>
            <a href="#statped_merknad">
               <span class="lic">
                  <span xml:lang="no" lang="no">Merknad</span>
               </span>
            </a>
         </li>
         <xsl:apply-templates select="node()"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="ol[ancestor::section[f:types(.) = 'toc'] and count(ancestor::li) ge 2]"/>
   <xsl:template match="li[ancestor::section[f:types(.) = 'toc']]">
      <xsl:copy exclude-result-prefixes="#all">
         <xsl:apply-templates select="@*"/>
         <xsl:value-of select="concat('xxx', count(ancestor-or-self::li), ' ')"/>
         <xsl:apply-templates select="node()"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="li[ancestor::section[f:types(.) = 'toc'] and matches(., '^Kolofon')]" priority="2"/>
   <xsl:template match="body">
      <xsl:copy exclude-result-prefixes="#all">
         <xsl:apply-templates select="@*"/>
         <xsl:variable name="title" select="/*/head/title/text()"/>
         <!--  select="/*/head/meta[@name = 'dc:language']/@content"/> -->
         <xsl:variable name="language" select="
               for $language in (/*/head/meta[@name = 'dc:language']/@content)
               return
                  replace($language, '^(.*), *(.*)$', '$2 $1')"/>
         <xsl:variable name="authors" select="
               for $author in (/*/head/meta[@name = 'dc:creator']/@content)
               return
                  replace($author, '^(.*), *(.*)$', '$2 $1')"/>
         <xsl:variable name="publisher-original" select="/*/head/meta[@name = 'dc:publisher.original']/@content"/>
         <xsl:variable name="publisher" select="/*/head/meta[@name = 'dc:publisher']/@content"/>
         <xsl:variable name="publisher-location" select="/*/head/meta[@name = 'dc:publisher.location']/@content"/>
         <xsl:variable name="issued" select="/*/head/meta[@name = 'dc:date.issued']/@content"/>
         <xsl:variable name="issued-original" select="/*/head/meta[@name = 'dc:issued.original']/@content"/>
         <xsl:variable name="edition-original" select="/*/head/meta[@name = 'schema:bookEdition.original']/@content"/>
         <xsl:variable name="edition-original" select="replace($edition-original, '^(\d+\.?)$', '$1.utg.')"/>
         <!-- Replace "1" with "1.utg." -->
         <xsl:variable name="edition-original" select="replace($edition-original, '\.+', '.')"/>
         <!-- Replace "1..utg." with "1.utg." -->
         <xsl:variable name="pagebreaks" select="(//div | //span)[f:types(.) = 'pagebreak']"/>
         <xsl:variable name="first-page" select="
               if ($pagebreaks[1]/@title) then
                  $pagebreaks[1]/@title
               else
                  $pagebreaks[1]/text()"/>
         <xsl:variable name="last-page" select="
               if ($pagebreaks[last()]/@title) then
                  $pagebreaks[last()]/@title
               else
                  $pagebreaks[last()]/text()"/>
         <xsl:variable name="isbn" select="/*/head/meta[@name = 'schema:isbn']/@content"/>
         <p>
            <xsl:attribute name="xml:lang">no</xsl:attribute>
            <xsl:attribute name="lang">no</xsl:attribute>
            <xsl:value-of select="$title"/>
            <!--   <xsl:if test="$language">
                    <xsl:value-of select="concat(' - ', $language)"/>
                </xsl:if> -->
            <xsl:choose>
               <xsl:when test="count($language) gt 1">
                  <xsl:text> - </xsl:text>
                  <xsl:value-of select="string-join($language[position() lt last()], ', ')"/>
                  <xsl:text>/</xsl:text>
                  <xsl:value-of select="$language[last()]"/>
               </xsl:when>
               <xsl:when test="count($language) = 1">
                  <xsl:text> - </xsl:text>
                  <xsl:value-of select="$language"/>
               </xsl:when>
               <xsl:otherwise>
                  <!-- No language -->
               </xsl:otherwise>
            </xsl:choose>
            <br/>
            <xsl:value-of select="
                  if ($first-page) then
                     concat('(s. ', $first-page, '-', $last-page, ')')
                  else
                     ''"/>
            <xsl:choose>
               <xsl:when test="count($authors) gt 1">
                  <xsl:text> - </xsl:text>
                  <xsl:value-of select="string-join($authors[position() lt last()], ', ')"/>
                  <xsl:text> og </xsl:text>
                  <xsl:value-of select="$authors[last()]"/>
               </xsl:when>
               <xsl:when test="count($authors) = 1">
                  <xsl:text> - </xsl:text>
                  <xsl:value-of select="$authors"/>
               </xsl:when>
            </xsl:choose>
            <br/>
            <xsl:value-of select="$publisher-original"/>
            <xsl:value-of select="
                  if ($issued-original) then
                     concat(' ', $issued-original)
                  else
                     ''"/>
            <xsl:value-of select="
                  if ($edition-original) then
                     concat(' - ', $edition-original)
                  else
                     ''"/>
            <xsl:value-of select="
                  if ($isbn) then
                     concat(' - ISBN: ', $isbn)
                  else
                     ''"/>
         </p>
         <xsl:apply-templates select="section[f:types(.) = 'toc']"/>
         <div>
            <p/>
            <h1 id="statped_merknad">
               <span xml:lang="no" lang="no">xxx1 Generell merknad for Statpeds leselistbøker:</span>
            </h1>
            <p>
               <span xml:lang="no" lang="no">Filen har en klikkbar innholdsfortegnelse.</span>
            </p>
            <p>
               <span xml:lang="no" lang="no">xxx innleder overskrifter. Overskriftsnivået vises med tall: xxx1, xxx2 osv.</span>
            </p>
            <p>
               <span xml:lang="no" lang="no">--- innleder sidetallet.</span>
            </p>
            <p>
               <span xml:lang="no" lang="no">Uthevingstegnet er slik: _.</span>
            </p>
            <p>
               <span xml:lang="no" lang="no">Eksempel: _Denne setningen er uthevet._</span>
            </p>
            <p>
               <span xml:lang="no" lang="no">Ordforklaringer, gloser eller stikkord finner du etter hovedteksten og eventuelle bilder.</span>
            </p>
            <p>
               <span xml:lang="no" lang="no">Eventuelle stikkordsregistre og kilder er utelatt. Kolofonen og baksideteksten finner du til slutt i denne filen.</span>
            </p>
         </div>
         <!--   <xsl:apply-templates select="* except section[f:types(.) = ('toc', 'backmatter', 'index', 'titlepage', 'colophon') and f:classes(.) = ('rearcover')] "/>-->
         <!--  <xsl:apply-templates select="* except section[f:types(.) = ('toc', 'backmatter', 'index', 'colophon', 'titlepage', 'cover')]"/> -->
         <xsl:apply-templates select="* except section[f:types(.) = ('toc', 'backmatter', 'index', 'colophon', 'titlepage', 'cover')]"/>
         <p/>
         <p>Ettertekst:</p>
         <xsl:apply-templates select="section[f:types(.) = 'backmatter' and not(f:types(.) = 'index' or f:types(.) = 'colophon')]"/>
         <p/>
         <p>Kolofon:</p>
         <xsl:apply-templates select="section[f:types(.) = 'colophon']"/>
         <p/>
         <p>Baksidetekst:</p>
         <xsl:apply-templates select="section[f:types(.) = 'cover']/section[f:classes(.) = 'rearcover']"/>
         <p/>

<!-- ny tekst -  test nnorsk eller norsk -->
   

         <xsl:choose>
         <xsl:when test="//meta[@name='dc:language']/string(@content)= 'nn'">
           <p>
              <span xml:lang="nn" lang="nn">Opphavsrett Statped:<br>Denne boka er lagd til rette for elevar med synssvekking. Ifølgje lov om opphavsrett kan ho ikkje brukast av andre. Teksten er tilpassa for lesing med skjermlesar og leselist. Kopiering er berre tillate til eige bruk. Brot på desse avtalevilkåra, slik som ulovleg kopiering eller medverknad til ulovleg kopiering, kan medføre ansvar etter åndsverklova.</br></span>
              
            </p>

             </xsl:when>

         <xsl:otherwise>

             <p>
            <span xml:lang="no" lang="no">Opphavsrett Statped:<br>Denne boka er tilrettelagt for elever med synssvekkelse. Ifølge lov om opphavsrett kan den ikke brukes av andre. Teksten er tilpasset for lesing med skjermleser og leselist. Kopiering er kun tillatt til eget bruk. Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til ulovlig kopiering, kan medføre ansvar etter åndsverkloven.</br></span>
            </p>

          </xsl:otherwise>

       </xsl:choose>
   

        
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="section[f:types(.) = 'colophon']/*[matches(name(), 'h[1-6]')]" />

   <xsl:template match="em | strong">
      <xsl:text>_</xsl:text>
      <xsl:apply-templates select="node()"/>
      <xsl:text>_</xsl:text>
   </xsl:template>
   <xsl:template match="table">
      <!-- Insert text Tabell: -->
      <xsl:if test="not(descendant::span[f:types(.) = 'pagebreak'])">
         <p />
      </xsl:if>
      <p>Tabell: <xsl:apply-templates select="./caption/node()"/></p>
      <table>
         <xsl:apply-templates select="node() except ./caption"/>
      </table>
   </xsl:template>
   <!-- xsl:template match="ol[following-sibling::*][1][name() = 'ol' or name() = 'ul'] | ul[following-sibling::*][1][name() = 'ol' or name() = 'ul']" -->
   <xsl:template match="ol[not(ancestor::ol or ancestor::ul)] | ul[not(ancestor::ol or ancestor::ul)]">
      <xsl:next-match/>
      <p></p>
   </xsl:template>
   <xsl:template match="ul[f:classes(.) = 'list-unstyled']" priority="2">
      <xsl:for-each select="li">
         <p>
            <xsl:if test="not(ancestor::table)">
               <xsl:text>STATPED_DUMMYTEXT_LIST_UNSTYLED</xsl:text>
            </xsl:if>
            <xsl:apply-templates />
         </p>
      </xsl:for-each>
      <xsl:if test="not(exists(ancestor::table | ancestor::ul | ancestor::ol))">
         <p/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="head">
      <xsl:copy exclude-result-prefixes="#all">
         <xsl:apply-templates select="@*"/>
         <xsl:apply-templates select="node()"/>
         <xsl:element name="style">
            <xsl:text>div.pagebreak {page-break-after:avoid;}</xsl:text>
         </xsl:element>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="dl">
         <xsl:for-each-group select="dt | dd" group-starting-with="dt">
            <p>STATPED_DUMMYTEXT_DL<xsl:apply-templates select="current-group()"/></p>
               <!-- apply templates to the dt and all directly following dd elements -->
         </xsl:for-each-group>
   </xsl:template>
   <xsl:template match="p[not(preceding-sibling::*[1][self::p]) and following-sibling::*[1][self::dl]]">
         <p>STATPED_DUMMYTEXT_P_BEFORE_DL<xsl:apply-templates /></p>
   </xsl:template>
   <xsl:template match="sub">
      <xsl:text>\</xsl:text>
      <xsl:if test="string-length(.) gt 1">
         <xsl:text>(</xsl:text>
      </xsl:if>
      <xsl:apply-templates />
      <xsl:if test="string-length(.) gt 1">
         <xsl:text>)</xsl:text>
      </xsl:if>
   </xsl:template>
   <xsl:template match="sup">
      <xsl:text>^</xsl:text>
      <xsl:if test="string-length(.) gt 1">
         <xsl:text>(</xsl:text>
      </xsl:if>
      <xsl:apply-templates />
      <xsl:if test="string-length(.) gt 1">
         <xsl:text>)</xsl:text>
      </xsl:if>
   </xsl:template>

   <!-- remove sound-text, blocks inside /.../ or [...] -->
   <xsl:template match="dt//text() | dd//text()">
      <xsl:variable name="textValue" select="replace(., '/[^/]*?/', '')"/>
      <xsl:variable name="textValue" select="replace($textValue, '\[[^\]]*?\]', '')"/>
      <xsl:variable name="textValue" select="replace($textValue, '\s*:\s*$', ': ')"/>
      <xsl:variable name="textValue" select="replace($textValue, '^\s*:\s*', ': ')"/>
      <xsl:value-of select="replace($textValue, '\[[^\]]*?\]', '')"/>
   </xsl:template>
   <xsl:template match="dt" priority="10">
      <!-- rename to span -->
      <xsl:element name="span">
         <xsl:apply-templates select="@* | node()"/>
      </xsl:element>
   </xsl:template>
   <xsl:template match="dd" priority="10">
      <!-- rename to span -->
      <xsl:element name="span">
         <xsl:apply-templates select="@* | node()"/>
      </xsl:element>
   </xsl:template>
   <!-- ******* [not(self::dd)]***************-->
   <!-- xsl:template match="p[@xml:lang | @lang]">
      <xsl:copy exclude-result-prefixes="#all">
         <xsl:apply-templates select="@* except (@xml:lang | @lang)"/>
         <xsl:element name="span">
            <xsl:apply-templates select="@xml:lang | @lang"/>
            <xsl:apply-templates select="node()"/>
         </xsl:element>
      </xsl:copy>
   </xsl:template -->
   <xsl:function name="f:types">
      <xsl:param name="element" as="element()"/>
      <xsl:sequence select="tokenize($element/@epub:type, '\s+')"/>
   </xsl:function>
   <xsl:function name="f:classes">
      <xsl:param name="element" as="element()"/>
      <xsl:sequence select="tokenize($element/@class, '\s+')"/>
   </xsl:function>
</xsl:stylesheet>