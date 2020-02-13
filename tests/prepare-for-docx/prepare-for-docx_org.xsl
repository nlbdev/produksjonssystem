<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:epub="http://www.idpf.org/2007/ops"
    xmlns:f="#" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <xsl:output method="xhtml" indent="no" include-content-type="no"/>

    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy copy-namespaces="no" exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="h1[not(ancestor::section[f:types(.) = 'toc'])]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx1 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="h2[not(ancestor::section[f:types(.) = 'toc'])]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx2 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
   
    <xsl:template match="h3[not(ancestor::section[f:types(.) = 'toc'])]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx3 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="h4[not(ancestor::section[f:types(.) = 'toc'])]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx4 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="h5[not(ancestor::section[f:types(.) = 'toc'])]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx5 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="h6[not(ancestor::section[f:types(.) = 'toc'])]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx6 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template name="create-pagebreak">
        <xsl:variable name="page-number"
            select="
                if (@title) then
                    @title
                else
                    text()"/>
        <xsl:variable name="max-page-number"
            select="
                (//div | //span)[f:types(.) = 'pagebreak'][last()]/(if (@title) then
                    @title
                else
                    text())"/>
        
                 
        <div epub:type="pagebreak">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="title" select="$page-number"/>
            <xsl:value-of select="concat('--- ', $page-number, ' til ', $max-page-number)"/>
        </div>
    </xsl:template>

    <xsl:template match="div[f:types(.) = 'pagebreak']">
         <xsl:call-template name="create-pagebreak"/> 
    </xsl:template>

    <xsl:template match="span[f:types(.) = 'pagebreak']">
        <xsl:if
            test="not(exists(ancestor::h1 | ancestor::h2 | ancestor::h3 | ancestor::h4 | ancestor::h5 | ancestor::h6  | ancestor::p))">
               <xsl:call-template name="create-pagebreak"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6 | p" priority="10">
        <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
           <xsl:call-template name="create-pagebreak"/> 
        </xsl:for-each>

        <xsl:next-match/>
    </xsl:template>
  
        <xsl:template match="aside[f:classes(.) = 'sidebar']">
           
            <p lang="no" xml:lang="no">{{Rammetekst:}}</p>
            <xsl:apply-templates select="node()"/>
            <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Slutt}}</p>
            
        </xsl:template>
    
    <xsl:template match="div[f:classes(.) = 'linegroup']">
        <xsl:element name="div">
        <p lang="no" xml:lang="no">{{Rammetekst:}}</p>
        <xsl:apply-templates select="node()"/>
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Slutt}}</p>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="div[f:classes(.) = 'ramme1'] | div[f:classes(.) = 'ramme2'] | div[f:classes(.) = 'ramme3'] | div[f:classes(.) = 'ramme4'] | div[f:classes(.) = 'ramme5'] | div[f:classes(.) = 'ramme6']">
        <xsl:element name="div">
        <p lang="no" xml:lang="no">{{Rammetekst:}}</p>
        <xsl:apply-templates select="node()"/>
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Slutt}}</p>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="section[f:classes(.) = 'oppgaver3']/h1 | section[f:classes(.) = 'oppgaver3']/h2 | section[f:classes(.) = 'oppgaver3']/h3 | section[f:classes(.) = 'oppgaver3']/h4 | section[f:classes(.) = 'oppgaver3']/h5 | section[f:classes(.) = 'oppgaver3']/h6 ">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>>>> </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
         
    </xsl:template>
    
    
    <xsl:template match="section[f:classes(.) = 'oppgaver1']/ol/li | section[f:classes(.) = 'oppgaver2']/ol/li">
            <li>
                <xsl:apply-templates select="@*"/>
                <xsl:text>>>> </xsl:text>
                <xsl:apply-templates select="node()"/>
            </li> 
     </xsl:template>
    
  
    <xsl:template match="section[f:classes(.) = 'oppgaver1']/ol/li/p | section[f:classes(.) = 'oppgaver2']/ol/li/p">
        <li>
            <xsl:apply-templates select="@*"/>
            <xsl:text>>>> </xsl:text>
            <xsl:apply-templates select="node()"/>
        </li> 
    </xsl:template>
    
    
    <xsl:template match="img">
        <xsl:variable name="is-inside-figure"
        select="exists(parent::figure[f:classes(.) = 'image'])"/>
        <xsl:if test="string-length(@alt) gt 0">
        <xsl:if test="not($is-inside-figure)">
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Bilde:}}</p>                
        </xsl:if>            
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute><xsl:value-of select="concat('Forklaring: ', @alt)"/></p>
        <xsl:if test="not($is-inside-figure)">
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Slutt}}</p> 
        </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="figure[f:classes(.) = 'image']">
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Bilde:}}</p>        
        <xsl:copy exclude-result-prefixes="#all">
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates select="node()"/>
        </xsl:copy>
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>{{Slutt}}</p>     
    </xsl:template>
    
    <xsl:template name="unordered" match="//ul/li">
        <xsl:if test="exists(ul)"> 
            <xsl:if test="exists(text())"> 
            <li>
            <xsl:text>-- </xsl:text>
            <xsl:value-of select="text()"/>
            </li>
        </xsl:if>
            <xsl:apply-templates select="node()"/>    
        </xsl:if> 
    </xsl:template>

    <xsl:template match="figure[f:classes(.) = 'image']/aside">
              <xsl:choose>
                <xsl:when test="exists(p)">                 
                <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute><xsl:value-of select="p"/></p> 
                    <xsl:call-template name="unordered"/> 
                </xsl:when>
                <xsl:otherwise>
                <xsl:text>Bildetekst: </xsl:text>
                </xsl:otherwise>    
              </xsl:choose>
             
        <!--  </xsl:copy> -->
    </xsl:template>    
    
    
    <xsl:template match="figure[f:classes(.) = 'image']/figcaption">
    <xsl:copy exclude-result-prefixes="#all">
    <xsl:apply-templates select="@*"/>
    <xsl:choose>
    <xsl:when test="exists(p)">
 
      <xsl:text>Bildetekst: </xsl:text> 
    </xsl:when>
    <xsl:otherwise>                   
    <xsl:text>Bildetekst: </xsl:text>                
    </xsl:otherwise>                
    </xsl:choose>
    <xsl:apply-templates select="node()"/>
    </xsl:copy>
    </xsl:template>

    <xsl:template match="section[f:types(.) = 'toc']">
    <xsl:copy exclude-result-prefixes="#all">
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates select="node()"/>
    </xsl:copy>
    </xsl:template>

    <xsl:template match="ol[parent::section[f:types(.) = 'toc']]">
    <xsl:copy exclude-result-prefixes="#all">
    <xsl:apply-templates select="@*"/>
    <li  lang="no" xml:lang="no">xxx1 <a href="#statped_merknad"> <span class="lic">Merknad</span></a></li>
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

    <xsl:template match="body">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>

            <xsl:variable name="title" select="/*/head/title/text()"/>
            
            <!--  select="/*/head/meta[@name = 'dc:language']/@content"/> -->
            <xsl:variable name="language" 
              
                select="
                for $language in (/*/head/meta[@name = 'dc:language']/@content)
                return
                replace($language, '^(.*), *(.*)$', '$2 $1')"/>
           
            <xsl:variable name="authors"
                select="
                    for $author in (/*/head/meta[@name = 'dc:creator']/@content)
                    return
                        replace($author, '^(.*), *(.*)$', '$2 $1')"/>
            <xsl:variable name="publisher-original"
                select="/*/head/meta[@name = 'dc:publisher.original']/@content"/>
            <xsl:variable name="publisher" select="/*/head/meta[@name = 'dc:publisher']/@content"/>
            <xsl:variable name="publisher-location"
                select="/*/head/meta[@name = 'dc:publisher.location']/@content"/>
            <xsl:variable name="issued" select="/*/head/meta[@name = 'dc:date.issued']/@content"/>
            <xsl:variable name="issued-original"
                select="/*/head/meta[@name = 'dc:issued.original']/@content"/>
            <xsl:variable name="edition-original"
                select="/*/head/meta[@name = 'schema:bookEdition.original']/@content"/>
            <xsl:variable name="edition-original"
                select="replace($edition-original, '^(\d+\.?)$', '$1.utg.')"/>
            <!-- Replace "1" with "1.utg." -->
            <xsl:variable name="edition-original" select="replace($edition-original, '\.+', '.')"/>
            <!-- Replace "1..utg." with "1.utg." -->
            <xsl:variable name="pagebreaks" select="(//div | //span)[f:types(.) = 'pagebreak']"/>
            <xsl:variable name="first-page"
                select="
                    if ($pagebreaks[1]/@title) then
                        $pagebreaks[1]/@title
                    else
                        $pagebreaks[1]/text()"/>
            <xsl:variable name="last-page"
                select="
                    if ($pagebreaks[last()]/@title) then
                        $pagebreaks[last()]/@title
                    else
                        $pagebreaks[last()]/text()"/>
            <xsl:variable name="isbn" select="/*/head/meta[@name = 'schema:isbn']/@content"/>

            <p>
                <xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>
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

                <xsl:value-of
                    select="
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
                    <xsl:otherwise>
                        <!-- No authors -->
                    </xsl:otherwise>
                </xsl:choose>
                <br/>

                <xsl:value-of select="$publisher-original"/>
                <xsl:value-of
                    select="
                        if ($issued-original) then
                            concat(' ', $issued-original)
                        else
                            ''"/>
                <xsl:value-of
                    select="
                        if ($edition-original) then
                            concat(' - ', $edition-original)
                        else
                            ''"/>
                <xsl:value-of
                    select="
                        if ($isbn) then
                            concat(' - ISBN: ', $isbn)
                        else
                            ''"
                />
            </p>

            <p lang="no" xml:lang="no">Denne boka er tilrettelagt for synshemmede. Ifølge lov om opphavsrett kan den ikke brukes av andre. Kopiering er kun tillatt til eget bruk. Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til ulovlig kopiering, kan medføre ansvar etter åndsverkloven.<br/>
                <xsl:value-of select="$publisher-location"/>
                <xsl:value-of
                    select="
                        if ($issued) then
                            concat(' ', $issued)
                        else
                            ''"/>
                <xsl:value-of
                    select="
                        if ($publisher) then
                            concat(', ', $publisher)
                        else
                            ''"/>
                <xsl:value-of select="'.'"/>
            </p>
            <xsl:apply-templates select="section[f:types(.) = 'toc']"/>
           
            <section>
                <h1 id="statped_merknad" lang="no" xml:lang="no">xxx1 Merknad</h1>
                <p lang="no" xml:lang="no">-- Overskrifter: Den klikkbare innholdsfortegnelsen i denne filen viser to av de fire overskriftsnivåene som er merket med xxx.</p>
                <p lang="no" xml:lang="no">-- Rammetekster og bilder som dukker opp midt i løpende tekst, er flyttet, slik at de står etter den løpende teksten, foran neste overskrift.</p>
                <p lang="no" xml:lang="no">-- Sidetallet står øverst på siden, på egen linje, med åpen linje over, slik:</p>
                <p lang="no" xml:lang="no"> --- 10 til 79</p>
                <p lang="no" xml:lang="no"> der 10 er aktuelt sidetall og 79 er sluttsidetalet i originalboka.</p>
                <p lang="no" xml:lang="no"> -- Uthevingstegnet er slik: _</p>
                <p lang="no" xml:lang="no"> Eksempel: _Denne setningen er uthevet._</p>
                <p lang="no" xml:lang="no"> -- {{}} Doble klammeparenteser brukes rundt opplysninger om layout eller spesielle elementer på siden.</p>
                <p lang="no" xml:lang="no"> -- Oppgavene under overskriften _xxx3 Refleksjon_ i boka er nummerert og markert med >>> slik: 1. >>>, 2. >>> osv., slik at du enkelt kan søke deg frem til dem.</p>
                <p lang="no" xml:lang="no"> -- Liste over sentrale begreper, Litteraturliste, Læreplan, Stikkordregister og innhold for hele boka finner du til slutt i denne filen.</p>
            </section>
            <xsl:apply-templates select="* except section[f:types(.) = 'toc']"/>
           
        </xsl:copy>
    </xsl:template>

    <xsl:template match="section[f:types(.) = 'titlepage']"/>
    <xsl:template match="section[f:types(.) = 'colophon']"/>
    <xsl:template match="section[f:types(.) = 'index']"/>
   
    
    <!-- _______________________________ -->
    <xsl:template match="//em">
        <!-- replace em with '_' -->
      
        <xsl:text>_</xsl:text>
        <xsl:apply-templates select="node()"/>
        <xsl:text>_</xsl:text>
        
    
    </xsl:template>
    <xsl:template match="//strong">
        <!-- replace strong with '_' -->
        
        <xsl:text>_</xsl:text>
        <xsl:apply-templates select="node()"/>
        <xsl:text>_</xsl:text>
    </xsl:template>
    
    <xsl:template match="li/a/span/strong">
        <!-- replace string with '' (ref toc) -->
        
        <xsl:text></xsl:text>
        <xsl:apply-templates select="node()"/>
        <xsl:text></xsl:text>
    </xsl:template>
    
  
   
    <xsl:template match="ol[ancestor::section[not(f:types(.) = 'toc')]]/li/p">
        <p><xsl:apply-templates select="node()"/></p>
    </xsl:template>
    
    <xsl:template match="ul/li[not(*)]">
        <li>
        <xsl:text>-- </xsl:text>
        <xsl:apply-templates select="node()"/>
        </li>
    </xsl:template> 
    
    <xsl:template match="ul/li/p">
        <li>
            <xsl:text>-- </xsl:text>
            <xsl:apply-templates select="node()"/>
        </li>
    </xsl:template> 
    
    <xsl:template match="figcaption/p">
            <xsl:apply-templates select="text()"/>        
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
        <xsl:element name="ul"> 
            <xsl:attribute name="class">list-style-type-none</xsl:attribute> 
            <xsl:attribute name="style">list-style-type: none;</xsl:attribute>
            <xsl:for-each-group select="dt | dd" group-starting-with="dt">
                <xsl:element name="li">
                    <!-- apply templates to the dt and all directly following dd elements -->
                    <xsl:apply-templates select="current-group()"/>
                </xsl:element>
            </xsl:for-each-group>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="dt">
        <!-- rename to span -->
        <xsl:element name="span">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="dd">
        <!-- rename to span -->
        <xsl:element name="span">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    
    
    
    <xsl:function name="f:types">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type, '\s+')"/>
    </xsl:function>

    <xsl:function name="f:classes">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@class, '\s+')"/>
    </xsl:function>

</xsl:stylesheet>
