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
        
           <p></p>   
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
            <xsl:element name="aside">
            <p lang="no" xml:lang="no"></p>
            <xsl:apply-templates select="node()"/>
           
            </xsl:element>
        </xsl:template>
    
    <xsl:template match="div[f:classes(.) = 'linegroup']">
        <xsl:element name="div">
        <p lang="no" xml:lang="no"></p>
        <xsl:apply-templates select="node()"/>
       
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="div[f:classes(.) = 'ramme1'] | div[f:classes(.) = 'ramme2'] | div[f:classes(.) = 'ramme3'] | div[f:classes(.) = 'ramme4'] | div[f:classes(.) = 'ramme5'] | div[f:classes(.) = 'ramme6']">
        <xsl:element name="div">
        <p lang="no" xml:lang="no"></p>
        <xsl:apply-templates select="node()"/>
       
        </xsl:element>
    </xsl:template>
    
      
    
    <xsl:template match="div[f:classes(.) = 'ramdoc']">
        <p></p>
        <xsl:element name="div">
            <p lang="no" xml:lang="no">Ramme:</p>
            <xsl:apply-templates select="node()"/>
           
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="aside[f:classes(.) = 'ramdoc']">
        <p></p>
        <xsl:element name="aside">
            <p lang="no" xml:lang="no">Ramme:</p>
            <xsl:apply-templates select="node()"/>
          
        </xsl:element>
    </xsl:template>
    
   
    <xsl:template match="section[f:classes(.) = 'oppgaver1'] | section[f:classes(.) = 'oppgaver2'] | section[f:classes(.) = 'oppgaver3']">
       <section>
                
      
           <xsl:apply-templates select="node()"/>
        
        
       </section>
    </xsl:template>
    
    
  
    
    
    <xsl:template match="img">
        
        <xsl:variable name="is-inside-figure"
        select="exists(parent::figure[f:classes(.) = 'image'])"/>
        <xsl:if test="string-length(@alt) gt 0">
        <xsl:if test="not($is-inside-figure)">
            <p></p>
            <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>Bilde:</p>                
        </xsl:if>            
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute><xsl:value-of select="concat('Forklaring: ', @alt)"/></p>
        <xsl:if test="not($is-inside-figure)">
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute></p> 
        </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="figure[f:classes(.) = 'image']">
        <p></p>
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute>Bilde:</p>        
        <xsl:copy exclude-result-prefixes="#all">
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates select="node()"/>
        </xsl:copy>
        <p><xsl:attribute name="lang">no</xsl:attribute><xsl:attribute name="xml:lang">no</xsl:attribute></p>     
    </xsl:template>
    
    
           
        
         
        

    <xsl:template match="figure[f:classes(.) = 'image']/aside" priority="11">
            <xsl:apply-templates select="node()"/>  
      
    </xsl:template>     
    
  
    
    
    <xsl:template match="figure[f:classes(.) = 'image']/figcaption">
    <xsl:copy exclude-result-prefixes="#all">
    <xsl:apply-templates select="@*"/>
    <xsl:text> Bildetekst: </xsl:text> 
    <xsl:apply-templates select="node()"/>
    </xsl:copy>
    </xsl:template>

   
    <xsl:template match="section[f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[f:types(.) = 'frontmatter colophon']">
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
            <xsl:variable name="pagebreaks" select="(//section | //span)[f:types(.) = 'pagebreak']"/>
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

          
            <xsl:apply-templates select="section[f:types(.) = 'toc']"/>
            
       
            <div>
                <h1 id="statped_merknad" lang="no" xml:lang="no">xxx1 Generell merknad for Statpeds leselistbøker:</h1>
                <p lang="no" xml:lang="no">Filen har en klikkbar innholdsfortegnelse.</p>
                <p lang="no" xml:lang="no">xxx innleder overskrifter. Overskriftsnivået vises med tall: xxx1, xxx2 osv.</p>
                <p lang="no" xml:lang="no">--- innleder sidetallet.</p>
                <p lang="no" xml:lang="no">Uthevingstegnet er slik: _.</p>
                <p lang="no" xml:lang="no">Eksempel: _Denne setningen er uthevet._</p>
                <p lang="no" xml:lang="no">Ordforklaringer, gloser eller stikkord finner du etter hovedteksten og eventuelle bilder.</p>
                <p lang="no" xml:lang="no">Eventuelle stikkordsregistre og kilder er utelatt. Kolofonen og baksideteksten finner du til slutt i denne filen.</p>
              </div>
            
         <!--   <xsl:apply-templates select="* except section[f:types(.) = ('toc', 'backmatter', 'index', 'titlepage', 'colophon') and f:classes(.) = ('rearcover')] "/>-->
            
          <!--  <xsl:apply-templates select="* except section[f:types(.) = ('toc', 'backmatter', 'index', 'colophon', 'titlepage', 'cover')]"/> -->
            <xsl:apply-templates select="* except section[f:types(.) = ('toc', 'backmatter', 'index', 'colophon', 'titlepage', 'cover')]"/>
            <p></p> 
            <p>Ettertekst: </p>
            <xsl:apply-templates select="section[f:types(.) = 'backmatter' and not(f:types(.) = 'index')]"/>
            <p></p> 
            <p>Kolofon: </p>
            <xsl:apply-templates select="section[f:types(.) = 'frontmatter' and f:types(.) = 'colophon']"/>
            <p></p> 
            <p>Baksidetekst: </p>
            <xsl:apply-templates select="section[f:types(.) = 'cover']/section[f:classes(.) = 'rearcover']"/>
            <p></p> 
            <p lang="no" xml:lang="no">Denne boka er tilrettelagt for synshemmede. Ifølge lov om opphavsrett kan den ikke brukes av andre. Kopiering er kun tillatt til eget bruk. Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til ulovlig kopiering, kan medføre ansvar etter åndsverkloven.<br/>Statped.</p>
        </xsl:copy>
       
    </xsl:template>


    <xsl:template match="section[f:types(.) = 'backmatter']">
             
        <xsl:apply-templates select="node()"/>
    </xsl:template>
    <xsl:template match="section[f:types(.) = 'frontmatter' and f:types(.) = 'colophon']">
        
   
        <xsl:apply-templates select="node()"/>
    </xsl:template>
    
    <xsl:template match="section[f:types(.) = 'cover']/section[f:classes(.) = 'rearcover']">
         
        <xsl:apply-templates select="node()"/>
      
    </xsl:template>
    
    <!-- <xsl:template match="p">
     
        <xsl:apply-templates select="node()"/>
      
        <xsl:for-each select="p">
            <p><xsl:value-of select="concat('&#160;&#160;&#160;', p)"/></p>
        </xsl:for-each>
        
       
     
      
      
      
      </xsl:template>--> 
 
    <xsl:template match="em">
        <!-- replace em with '_' -->
                 
        <xsl:text>_</xsl:text>
        <xsl:apply-templates select="node()"/>
        <xsl:text>_</xsl:text>
        
    
    </xsl:template>
    <xsl:template match="strong">
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
    
    <xsl:template match="table" >
        <!-- Insert text Tabell: -->
        <p></p> 
        <p>Tabell:</p>
        <table>
            <xsl:apply-templates select="node()"/>
        </table>
            
    </xsl:template>
  
        
        
   
    <xsl:template match="ol[ancestor::section[not(f:types(.) = 'toc')]]/li/p">
        <p><xsl:apply-templates select="node()"/></p>
    </xsl:template>
    
  <!--  <xsl:template match="ul/li[not(*)]">
        <li>
            <xsl:text>.. </xsl:text>
            <xsl:if test="exists(ul)"> 
               <xsl:value-of select="text()"/>
                
                <xsl:if test="exists(li)"> 
                    <li>
                        <xsl:text>.. </xsl:text>
                        <xsl:value-of select="node()"/>
                    </li>
                </xsl:if>
                
            </xsl:if>  
            <xsl:apply-templates select="node()"/>
        </li>
    </xsl:template>  -->
    
    
   <xsl:template match="ul/li">
        <li>
            <xsl:apply-templates select="@*"/>
            <xsl:text>-- </xsl:text>       
            <xsl:apply-templates select="node()"/>
        </li>
    </xsl:template> 
    
    <xsl:template match="ul[f:classes(.) = 'list-unstyled']/li">
        <li>
            <xsl:apply-templates select="@*"/>
            
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
