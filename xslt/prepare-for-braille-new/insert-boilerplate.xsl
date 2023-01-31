<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dtbook="http://www.daisy.org/z3986/2005/dtbook/"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:nlb="http://www.nlb.no/ns/pipeline/xslt"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:param name="braille-standard" select="'(dots:6)(grade:0)'"/>
    <xsl:param name="notes-placement" select="''"/>
    <xsl:param name="page-width" select="'38'"/>
    <xsl:param name="page-height" select="'29'"/>
    <xsl:param name="datetime" select="current-dateTime()"/>
    
    <xsl:variable name="contraction-grade" select="replace($braille-standard, '.*\(grade:(.*)\).*', '$1')"/>
    <xsl:variable name="line-width" select="xs:integer($page-width) - 6"/>
    
    <xsl:variable name="html-namespace" select="'http://www.w3.org/1999/xhtml'"/>
    <xsl:variable name="dtbook-namespace" select="'http://www.daisy.org/z3986/2005/dtbook/'"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html:html">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="* except html:body"/> <!-- also includes ol#generated-document-toc and ol#generated-volume-toc -->
            <xsl:choose>
                <!-- single body element => insert section after header -->
                <xsl:when test="count(html:body) = 1">
                    <xsl:for-each select="html:body">
                        <xsl:copy>
                            <xsl:apply-templates select="@*"/>
                            <xsl:apply-templates select="*[1][self::html:header]/(. | preceding-sibling::comment())"/>
                            <xsl:call-template name="generate-frontmatter"/>
                            <xsl:apply-templates select="node() except *[1][self::html:header]/(. | preceding-sibling::comment())"/>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:when>
                
                <!-- multiple body elements => create new body element -->
                <xsl:otherwise>
                    <xsl:apply-templates select="node() except html:body[1]/(. | following-sibling::node())"/>
                    <xsl:call-template name="generate-frontmatter"/>
                    <xsl:apply-templates select="html:body[1]/(. | following-sibling::node())"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:book[not(dtbook:frontmatter)]">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:element name="frontmatter" namespace="{namespace-uri()}">
                <xsl:call-template name="generate-frontmatter"/>
            </xsl:element>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:frontmatter">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="node() except dtbook:level1[1]/(. | following-sibling::node())"/>
            <xsl:call-template name="generate-frontmatter"/>
            <xsl:apply-templates select="dtbook:level1[1]/(. | following-sibling::node())"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="generate-frontmatter">
        <xsl:variable name="namespace-uri" select="namespace-uri()"/>
        
        <xsl:variable name="author" as="xs:string*">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:choose>
                        <xsl:when test="count(//dtbook:frontmatter/dtbook:docauthor)">
                            <xsl:sequence select="//dtbook:frontmatter/dtbook:docauthor/nlb:element-text(.)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="(//dtbook:head/dtbook:meta[@name = 'dc:Creator'])/string(@content)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="count(//html:body//html:*[tokenize(@epub:type,'\s+')='z3998:author'])"> 
                         <xsl:sequence select="//html:head/html:meta[@name='dc:creator']/string(@content)"/>
                         <!-- We don't use z3998:author-->
                         <!--  <xsl:sequence select="//html:body//html:*[tokenize(@epub:type,'\s+')='z3998:author']/nlb:element-text(.)"/>-->
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="//html:head/html:meta[@name='dc:creator']/string(@content)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="fulltitle" as="xs:string">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:choose>
                        <xsl:when test="count(//dtbook:frontmatter/dtbook:doctitle)">
                            <xsl:sequence select="//dtbook:frontmatter/dtbook:doctitle/nlb:element-text(.)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="string((//dtbook:head/dtbook:meta[@name = 'dc:Title'])[1]/@content)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="count(//html:body//html:*[tokenize(@epub:type,'\s+')='fulltitle'])">
                            <xsl:sequence select="(//html:body//html:*[tokenize(@epub:type,'\s+')='fulltitle'])[1]/nlb:element-text(.)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="string((//html:head/html:title)[1]/text())"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="title" as="xs:string?">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:sequence select="(//dtbook:frontmatter/dtbook:doctitle//*[@class='title'])[1]/nlb:element-text(.)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="(//html:body//html:*[tokenize(@epub:type,'\s+')='title'])[1]/nlb:element-text(.)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="subtitle" as="xs:string?">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:sequence select="(//dtbook:frontmatter/dtbook:doctitle//*[@class='subtitle'])[1]/nlb:element-text(.)"/>
                </xsl:when>
                <xsl:otherwise>
                         <xsl:sequence select="//html:head/html:meta[@name = 'dc:title.subTitle']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="translator" as="xs:string*">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'dc:Contributor.Translator']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'dc:contributor.translator']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
  <xsl:variable name="pef-id" as="xs:string*">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                     <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'nlbprod:identifier.braille']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'nlbprod:identifier.braille']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

         

        <xsl:variable name="language-id" as="xs:string*">
        <xsl:choose>
            <xsl:when test="$namespace-uri = $dtbook-namespace">
                <xsl:choose>
                    <xsl:when test="//dtbook:head/dtbook:meta[@name = 'dc:language']/string(@content)= 'nn'">
                         <xsl:sequence select="'Nynorsk'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="'Bokmål'"/>
                     </xsl:otherwise>
               </xsl:choose>
                 <!--  <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'dc:language']/string(@content)"/> -->
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:choose>
                     <xsl:when test="//html:head/html:meta[@name='dc:language']/string(@content)= 'nn'">
                        <xsl:sequence select="'Nynorsk'"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:sequence select="'Bokmål'"/>
                    </xsl:otherwise>
                 </xsl:choose>
                 <!--  <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'dc:language']/string(@content)"/> -->
                
                 <!--  <xsl:sequence select="//html:head/html:meta[@name='dc:language']/string(@content)"/> -->
                   
            </xsl:otherwise>
        </xsl:choose>
        </xsl:variable>

        <xsl:variable name="utgave-nummer" as="xs:string*">

            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                     <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'schema:bookEdition.original']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'schema:bookEdition.original']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

          <xsl:variable name="forlag" as="xs:string*">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                     <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'dc:publisher.original']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'dc:publisher.original']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

   <xsl:variable name="sted" as="xs:string*">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                     <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'dc:publisher.location.original']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'dc:publisher.location.original']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

         <xsl:variable name="årstall" as="xs:string*">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                     <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'dc:date.issued.original']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'dc:date.issued.original']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="forlag-sted-årstall" as="xs:string*">

              <xsl:sequence select="concat($forlag, ', ', $sted , ', ', $årstall)"/>       

        </xsl:variable>
         <xsl:variable name="utgave" as="xs:string*">
          <xsl:choose>
                <xsl:when test="$language-id = 'Bokmål'">
                    <xsl:sequence select="concat('Utgave  ', $utgave-nummer)"/>    
                </xsl:when>
                <xsl:when test="$language-id = 'Nynorsk'">
                <xsl:sequence select="concat('Utgåve  ', $utgave-nummer)"/>    
                 </xsl:when>
                 <xsl:otherwise>
                 <xsl:sequence select="concat('Utgave  ', $utgave-nummer)"/>    
                 </xsl:otherwise>
           </xsl:choose>
                   
        </xsl:variable>


        <xsl:variable name="original-publisher" as="xs:string?">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:sequence select="//dtbook:frontmatter/dtbook:level1[tokenize(@class,'\s+')='colophon']/dtbook:p[not(*) and starts-with(text(),'&#x00A9;')]/replace(text(),'^&#x00A9;\s+','')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:body[(tokenize(@class,'\s+'),tokenize(@epub:type,'\s+'))='colophon']/html:p[not(*) and starts-with(text(),'&#x00A9;')]/replace(text(),'^&#x00A9;\s+','')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="original-isbn" as="xs:string?">
            <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                    <xsl:sequence select="//dtbook:frontmatter/dtbook:level1[tokenize(@class,'\s+')='colophon']/dtbook:p[not(*) and matches(text(),'^(ISBN\s*)?[\d-]+$')]/replace(text(),'^(ISBN\s*)?([\d-]+)$','$1')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:body[(tokenize(@class,'\s+'),tokenize(@epub:type,'\s+'))='colophon']/dtbook:p[not(*) and matches(text(),'^(ISBN\s*)?[\d-]+$')]/replace(text(),'^(ISBN\s*)?([\d-]+)$','$1')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

          <xsl:variable name="isbn" as="xs:string?">
           <xsl:choose>
                <xsl:when test="$namespace-uri = $dtbook-namespace">
                     <xsl:sequence select="//dtbook:head/dtbook:meta[@name = 'schema:isbn.original']/string(@content)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="//html:head/html:meta[@name = 'schema:isbn.original']/string(@content)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="author-lines" select="nlb:author-lines($author, $line-width, 'mfl.')" as="xs:string*"/>
        <xsl:variable name="authors-fit" select="$author-lines[1] = 'true'" as="xs:boolean"/>
       <xsl:variable name="author-lines" select="$author-lines[position() gt 1]" as="xs:string*"/>
        <xsl:variable name="author-lines" select="if (count($author) gt 1 and not(count($author-lines))) then 'Flere forfattere' else $author-lines"/>
        
        
        <xsl:variable name="grade-text" as="xs:string">
            <xsl:choose>
                <xsl:when test="$contraction-grade = '0'">
                    <xsl:text>Fullskrift</xsl:text>
                </xsl:when>
                <xsl:when test="$contraction-grade = '1'">
                    <xsl:text>Kortskrift 1</xsl:text>
                </xsl:when>
                <xsl:when test="$contraction-grade = '2'">
                    <xsl:text>Kortskrift 2</xsl:text>
                </xsl:when>
                <xsl:when test="$contraction-grade = '3'">
                    <xsl:text>Kortskrift 3</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text><![CDATA[]]></xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:element name="{nlb:level-element-name($namespace-uri, /*)}" namespace="{$namespace-uri}">
            <xsl:attribute name="class" select="'pef-titlepage'"/>
            
            <!-- 3 empty rows before author --> 
            <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
            <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
            <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
            <xsl:variable name="lines-used" select="3"/>

      
    
      
       <xsl:choose>
       <xsl:when test="count($author)=1">  <!-- delimiter found use old style input from bibliofil -->            
         <xsl:if test="contains($author,';')"> 
          
        <xsl:variable name="v2" select="substring-before($author, ';')"/>
        <xsl:call-template name="row">
                    <xsl:with-param name="content" select="concat($v2,' mfl.')"/>
                    <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                       <xsl:with-param name="inline" select="true()"/>
                </xsl:call-template>
                </xsl:if>
                  <xsl:if test="not(contains($author,';'))">
                   <xsl:call-template name="row">
                    <xsl:with-param name="content" select="$author"/>
                    <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                       <xsl:with-param name="inline" select="true()"/>
                </xsl:call-template>

             </xsl:if>
       </xsl:when>
       <xsl:otherwise>       
        <xsl:for-each select="$author-lines">
        <xsl:variable name="parent-position" select="position()" />
        <xsl:choose>
            <xsl:when test="$parent-position = 1 and count($author-lines) = 1">
             <xsl:call-template name="row">
                    <xsl:with-param name="content" select="."/>
                    <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                </xsl:call-template>
            </xsl:when>
             <xsl:when test="$parent-position = 1 and count($author-lines) &gt; 1">
         
             <xsl:call-template name="row">
                    <xsl:with-param name="content" select="concat(.,' mfl.')"/>
                    <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                       <xsl:with-param name="inline" select="true()"/>
                </xsl:call-template>
            </xsl:when>
          </xsl:choose>
         </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>  

         <!---   <xsl:choose>
            <xsl:when test="count($author-lines) &gt 1">
                <xsl:sequence select="('true')"/>
            </xsl:when>
          </xsl:choose>-->
                  

            <!-- 2 empty rows before title -->
          
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>

              <!-- TITLE ON LINE 6-->  

              <xsl:call-template name="row">
                <xsl:with-param name="content" select="$fulltitle"/>
              
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
        
              </xsl:call-template>
     
         <xsl:choose>
            <xsl:when test="count($subtitle) = 0">
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
            </xsl:when>
               <xsl:when test="count($subtitle) &gt; 0">
                 <xsl:call-template name="row">
                <xsl:with-param name="content" select="$subtitle"/>
               
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
        
              </xsl:call-template>
            </xsl:when>
        </xsl:choose>

       
          
              <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
          
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
                 <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
  <!-- LANGUAGE ON LINE 14-->  
               <xsl:call-template name="row">
                <xsl:with-param name="content" select="$language-id"/>
                   <xsl:with-param name="classes" select="'Innrykk-5'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
  <!-- EDITION ON LINE 16-->         
              <xsl:call-template name="row">
                <xsl:with-param name="content" select="$utgave"/>
                   <xsl:with-param name="classes" select="'Innrykk-5'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
                <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>

     <!-- PUBLISHER  ON LINE 20-->             
              <xsl:call-template name="row">
                <xsl:with-param name="content" select="$forlag-sted-årstall"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

         
              <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
              <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
  <!-- CCCCCC  ON LINE 23-->  
        <!--    <xsl:call-template name="row">
                <xsl:with-param name="content" select="'cccccccccccccccccccccccccccccc'"/> 
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>-->
cccccccccccccccccccccccccccccccc
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="concat('Statped, ',format-dateTime($datetime, '[Y]'))"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
            
    
            <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
            <xsl:call-template name="empty-row"><xsl:with-param name="namespace-uri" select="$namespace-uri"/></xsl:call-template>
       <!-- VOLUME NO  ON LINE 27-->        
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="' av '"/>
                <xsl:with-param name="classes" select="'pef-volume'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
 <!-- PROD NO  ON LINE 28--> 
              <xsl:call-template name="row">
                <xsl:with-param name="content" select="$pef-id"/>
                 <xsl:with-param name="classes" select="'Høyre-justert'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
              
            </xsl:call-template>
        </xsl:element>
        
        <!-- end of titlepage, beginning of about page -->

        <xsl:variable name="notes-present" as="xs:boolean"
                      select="exists(//dtbook:note|//@epub:type[tokenize(.,'\s+') = ('note','footnote','endnote','rearnote')])"/>
        <xsl:variable name="notes-placement-text">
            <xsl:choose>
                <xsl:when test="$notes-placement = 'bottom-of-page'">
                    <xsl:text>Noter er plassert nederst på hver side.</xsl:text>
                </xsl:when>
                <xsl:when test="$notes-placement = 'end-of-volume'">
                    <xsl:text>Noter er plassert i slutten av hvert hefte.</xsl:text>
                </xsl:when>
                <xsl:when test="$notes-placement = 'end-of-book'">
                    <xsl:text>Noter er plassert bakerst i boken.</xsl:text>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="final-rows" as="element()*">
      <!--   <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Denne boka er skrevet av:'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

   
       <xsl:call-template name="SimpleStringLoop">
              <xsl:with-param name="input" select="$author"/>
              <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
        </xsl:call-template>--> 
     
            <xsl:choose>
                <xsl:when test="$language-id = 'Bokmål'">
                    <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Punktsidetallet er midtstilt nederst på siden.  '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Full celle i margen og foran sidetallet nederst til høyre markerer sideskift i originalboka. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Tekst og bilder kan være flyttet til en annen side for å unngå å bryte opp løpende tekst.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
               <xsl:call-template name="row">
               <xsl:with-param name="content" select="'Ordforklaringer og stikkord finner du som regel etter teksten de tilhører, etter eventuelle bilder. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
            
             <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Bildebeskrivelser står mellom punktene (56-3) og (6-23).'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

           <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Utheving markeres med punktene (23) foran og (56) bak teksten.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
                
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Boka skal ikke returneres.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
                </xsl:when>
                <xsl:when test="$language-id = 'Nynorsk'">
                    <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Punktsidetalet står i midten nedst på sida. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
                   <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Full celle i margen og framfor sidetalet nedst til høgre markerer sideskift i originalboka. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Tekst og bilete kan vere flytta til ei ny side, for ikkje å bryte opp den løpande teksten.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
             <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Ordforklaringar og stikkord finn du som regel etter den teksten dei høyrer til, etter eventuelle bilete. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
            
             <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Biletskildringar står mellom punkta (56-3) og (6-23).'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

           <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Utheving er markert med punkta (23) framfor og (56) bak teksten.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
                
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Du treng ikkje returnere boka.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
                </xsl:when>
                 <xsl:otherwise>
                  <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Punktsidetallet er midtstilt nederst på siden.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
                 <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Full celle i margen og foran sidetallet nederst til høyre markerer sideskift i originalboka. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Tekst og bilder kan være flyttet til en annen side for å unngå å bryte opp løpende tekst. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
              <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Ordforklaringer og stikkord finner du som regel etter teksten de tilhører, etter eventuelle bilder. '"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
             <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Bildebeskrivelser står mellom punktene (56-3) og (6-23).'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>

           <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Utheving markeres med punktene (23) foran og (56) bak teksten.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                <xsl:with-param name="inline" select="true()"/>
            </xsl:call-template>
                
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="'Boka skal ikke returneres.'"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>

         
           
        </xsl:variable>
        <xsl:element name="{nlb:level-element-name($namespace-uri, /*)}" namespace="{$namespace-uri}">
            <xsl:attribute name="class" select="'pef-about'"/>
            <xsl:element name="h1" namespace="{$namespace-uri}">
             <xsl:choose>
                <xsl:when test="$language-id = 'Bokmål'">
                    <xsl:text>Merknad til punktskriftutgaven</xsl:text>
                </xsl:when>
                <xsl:when test="$language-id = 'Nynorsk'">
                 <xsl:text>Merknad til punktskriftutgåva</xsl:text>
                 </xsl:when>
                 <xsl:otherwise>
                  <xsl:text>Merknad til punktskriftutgaven</xsl:text>
                 </xsl:otherwise>
           </xsl:choose>
            </xsl:element>
           
        
            <xsl:if test="not($notes-present and $notes-placement = 'bottom-of-page')">
                <xsl:if test="$notes-present">
                    <xsl:call-template name="row">
                        <xsl:with-param name="content" select="$notes-placement-text"/>
                        <xsl:with-param name="classes" select="'notes-placement'"/>
                        <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                    </xsl:call-template>
                </xsl:if>
                <xsl:sequence select="$final-rows"/>
            </xsl:if>
        </xsl:element>
        <!--
            in order for -obfl-use-when-collection-not-empty to work the "notes-placement" and
            "notes-placement-fallback" elements must be added to a named flow directly (not via
            their parent element)
        -->
        <xsl:if test="$notes-present and $notes-placement = 'bottom-of-page'">
            <xsl:call-template name="row">
                <xsl:with-param name="content" select="$notes-placement-text"/>
                <xsl:with-param name="classes" select="('pef-about','notes-placement')"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
            <xsl:call-template name="row">
                <xsl:with-param name="content">Noter er plassert i slutten av hvert hefte.</xsl:with-param>
                <xsl:with-param name="classes" select="('pef-about','notes-placement-fallback')"/>
                <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
            <xsl:element name="div" namespace="{$namespace-uri}">
                <xsl:attribute name="class" select="'pef-about'"/>
                <xsl:sequence select="$final-rows"/>
            </xsl:element>
        </xsl:if>
    </xsl:template>

      

    
    <xsl:template name="empty-row" as="element()">
        <xsl:param name="namespace-uri" as="xs:string"/>
        <xsl:call-template name="row">
            <xsl:with-param name="content" select="'&#160;'"/>
            <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="row" as="element()">
        <xsl:param name="content" as="xs:string"/>
        <xsl:param name="classes" as="xs:string*"/>
        <xsl:param name="namespace-uri" as="xs:string"/>
        <xsl:param name="inline" select="false()"/>
        <xsl:choose>
            <xsl:when test="$inline">
                <xsl:element name="p" namespace="{$namespace-uri}">
                    <xsl:element name="span" namespace="{$namespace-uri}">
                        <xsl:if test="exists($classes)">
                            <xsl:attribute name="class" select="$classes"/>
                        </xsl:if>
                        <xsl:value-of select="$content"/>
                    </xsl:element>
                </xsl:element>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="p" namespace="{$namespace-uri}">
                    <xsl:if test="exists($classes)">
                      <!--  <xsl:attribute name="class" select="string-join($classes,' ')"/> -->
                      <xsl:attribute name="class" select="$classes"/>
                    </xsl:if>
                    <xsl:value-of select="$content"/>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


     <xsl:template name="SimpleStringLoop">
        <xsl:param name="input" as="xs:string"/>
         <xsl:param name="classes" as="xs:string*"/>
         <xsl:param name="namespace-uri"/>
        <xsl:variable name="nb_char" select="string-length($input)-string-length(translate($input,';',''))"/>
      
       <xsl:choose>
       <xsl:when test="$nb_char !=0">  <!-- delimiter found-->
         
        <xsl:if test="string-length($input) &gt; 0">
            <xsl:variable name="v2" select="substring-before($input, ';')"/>
             <xsl:variable name="class2" select="$classes"/>
            <xsl:call-template name="row">
                    <xsl:with-param name="content" select="$v2" />
                     <xsl:with-param name="classes" select="$class2"/>
                      <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                        <xsl:with-param name="inline" select="true()"/>
                      </xsl:call-template>
            <xsl:call-template name="SimpleStringLoop">
                <xsl:with-param name="input" select="substring-after($input, ';')"/> 
                <xsl:with-param name="classes" select="$class2"/>  
                  <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
            </xsl:call-template>
               
        </xsl:if> 
      </xsl:when> 
      <xsl:otherwise>
        <xsl:call-template name="row">
                    <xsl:with-param name="content" select="$input" />
                     <xsl:with-param name="classes" select="'Innrykk-5'"/>
                      <xsl:with-param name="namespace-uri" select="$namespace-uri"/>
                        <xsl:with-param name="inline" select="true()"/>
                      </xsl:call-template>
      </xsl:otherwise>
</xsl:choose>
   
    </xsl:template>
   

    <xsl:function name="nlb:level-element-name" as="xs:string">
        <xsl:param name="namespace-uri" as="xs:string"/>
        <xsl:param name="document" as="element()"/>
        <xsl:choose>
            <xsl:when test="$namespace-uri = $dtbook-namespace">
                <xsl:sequence select="'level1'"/>
            </xsl:when>
            <xsl:when test="count($document/html:body) = 1">
                <xsl:sequence select="'section'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="'body'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
  <xsl:function name="nlb:element-text" as="xs:string?">
        <xsl:param name="element" as="element()"/>
        
        <xsl:variable name="result" as="xs:string*">
            <xsl:for-each select="$element/node()">
                <xsl:if test="(tokenize(@class,'\s+'), tokenize(@epub:type,'\s+')) = ('title', 'subtitle')">
                    <xsl:sequence select="'&#10;'"/>
                </xsl:if>
                <xsl:choose>
                    <xsl:when test="self::text()">
                        <xsl:sequence select="replace(.,'\s+',' ')"/>
                    </xsl:when>
                    <xsl:when test="(self::html:br | self::dtbook:br)[tokenize(@class,'\s+') = 'display-braille']">
                        <xsl:sequence select="'&#10;'"/>
                    </xsl:when>
                    <xsl:when test="self::*">
                        <xsl:sequence select="nlb:element-text(.)"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="if (count($result)) then replace(replace(replace(replace(string-join($result,''),'&#10; ',' &#10;'),' +',' '),'(^ | $)',''),'^&#10;+','') else ()"/>
    </xsl:function>

       <!-- nlb:braille-length accounts for capital letter braille characters, and number characters -->
    <xsl:function name="nlb:braille-length">
        <xsl:param name="string" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="not($string)">
                <xsl:value-of select="0"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="expanded-string" select="replace($string,'&#10;','')"/>                              <!-- ignore newline characters; they are only used to suggest line breaks -->
                <xsl:variable name="expanded-string" select="replace($expanded-string,'[A-Z]','aa')"/>                   <!-- braille character before upper case characters -->
                <xsl:variable name="expanded-string" select="replace($expanded-string,'(^|[^\d])(\d)','$1.$2')"/>        <!-- braille character before numbers -->
                <xsl:variable name="expanded-string" select="replace($expanded-string,'([^a-zA-Z0-9 ,.;:!-])','$1$1')"/> <!-- special characters might be represented with two braille characters -->
                <xsl:value-of select="string-length($expanded-string)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
 <xsl:function name="nlb:strings-to-lines-always-break" as="xs:string*">
        <xsl:param name="strings" as="xs:string*"/>
        <xsl:param name="line-length" as="xs:integer"/>
        <xsl:param name="try-length" as="xs:integer"/>
        
        <xsl:variable name="result" as="xs:string*">
            <xsl:analyze-string select="string-join($strings,' ')" regex=".{concat('{',$try-length,'}')}">
                <xsl:matching-substring>
                    <xsl:sequence select="."/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:sequence select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:sequence select="if ($try-length &gt; 1 and count($result[nlb:braille-length(.) &gt; $line-length])) then nlb:strings-to-lines-always-break($strings, $line-length, $try-length - 1) else $result"/>
    </xsl:function>
    

    <xsl:function name="nlb:strings-to-lines" as="xs:string*">
        <xsl:param name="strings" as="xs:string*"/>
        <xsl:param name="line-length" as="xs:integer"/>
        <xsl:param name="break-words" as="xs:string"/> <!-- never | avoid | always -->
        
        <xsl:if test="not($break-words = ('never','avoid','always'))">
            <xsl:message select="concat('in nlb:strings-to-lines, the break-words parameter must be either ''never'', ''avoid'', or ''always''. Was: ''',$break-words,'''')" terminate="yes"/>
        </xsl:if>
        
        <xsl:choose>
            <xsl:when test="$break-words = 'always'">
                <xsl:sequence select="nlb:strings-to-lines-always-break($strings, $line-length, $line-length)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="$break-words = 'never' and count($strings[nlb:braille-length(.) &gt; $line-length])">
                        <xsl:sequence select="()"/>
                    </xsl:when>
                    <xsl:when test="nlb:braille-length($strings[1]) &gt; $line-length">
                        <xsl:variable name="first-string" select="replace($strings[1], '&#10;', '')"/>
                        <xsl:variable name="braille-extras" select="max((floor($line-length div 3),nlb:braille-length($first-string) - string-length($first-string)))"/>
                        <xsl:sequence select="nlb:strings-to-lines((tokenize(replace($first-string,concat('^(.{',$line-length - $braille-extras,'})'),'$1 '),' '), $strings[position() &gt; 1]), $line-length, $break-words)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="first-line" as="xs:string?">
                            <xsl:variable name="potential-lines" as="xs:string*">
                                <xsl:for-each select="reverse(1 to count($strings))">
                                    <xsl:sequence select="replace(string-join($strings[position() &lt;= current()],' '),'^&#10;','')"/>
                                </xsl:for-each>
                            </xsl:variable>
                            <xsl:sequence select="($potential-lines[nlb:braille-length(.) &lt;= $line-length and not(contains(.,'&#10;'))])[1]"/>
                        </xsl:variable>
                        <xsl:sequence select="$first-line"/>
                        
                        <xsl:variable name="remaining-strings" select="$strings[position() &gt; count(tokenize($first-line,'\s+'))]"/>
                        <xsl:if test="count($remaining-strings)">
                            <xsl:sequence select="nlb:strings-to-lines($remaining-strings, $line-length, $break-words)"/>
                        </xsl:if>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

     <xsl:function name="nlb:fit-name-to-lines" as="xs:string*">
        <xsl:param name="name" as="xs:string"/>
        <xsl:param name="lines-available" as="xs:integer"/>
        <xsl:param name="line-length" as="xs:integer"/>
        <!-- returns: ( [true|false], line1?, ..., lineN? ) -->
        
        <xsl:variable name="tokenized-name" select="tokenize($name,' +')"/>
        
        <xsl:variable name="last-name" select="if (contains($name,',')) then substring-before($name,',') else $tokenized-name[position() &gt; 1][last()]"/>
        <xsl:variable name="first-name" select="if (contains($name,',')) then tokenize(normalize-space(substring-after($name,',')),' +')[1] else $tokenized-name[1]"/>
        <xsl:variable name="middle-name" select="if (contains($name,',')) then tokenize(normalize-space(substring-after($name,',')),' +')[position() &gt; 1] else $tokenized-name[not(position() = (1,last()))]"/>
        
        <xsl:variable name="tokenized-first-middle-last" select="($first-name, $middle-name, $last-name)"/>
        
        <xsl:variable name="full-name-never-break" select="nlb:strings-to-lines($tokenized-first-middle-last, $line-length, 'never')"/>
        <xsl:variable name="full-name-avoid-break" select="nlb:strings-to-lines($tokenized-first-middle-last, $line-length, 'avoid')"/>
        
        <xsl:choose>
            <xsl:when test="count($tokenized-name) = 0">
                <xsl:sequence select="'true'"/>
                <xsl:sequence select="()"/>
            </xsl:when>
            <xsl:when test="count($full-name-never-break) &gt; 0 and count($full-name-never-break) &lt;= $lines-available">
                <xsl:sequence select="'true'"/>
                <xsl:sequence select="$full-name-never-break"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="string(count($full-name-avoid-break) le $lines-available)"/>
                <xsl:sequence select="$full-name-avoid-break[position() le $lines-available]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="nlb:author-lines" as="xs:string*">
        <xsl:param name="authors" as="xs:string*"/>
        <xsl:param name="line-length" as="xs:integer"/>
        <xsl:param name="last-line-if-cropped" as="xs:string"/>
        <!-- returns: ( [true|false], line1?, line2?, line3? ) -->
        
        <xsl:choose>
            <xsl:when test="count($authors) = 0">
                <xsl:sequence select="('true')"/>
            </xsl:when>
            <xsl:when test="count($authors) = 1">
                <xsl:sequence select="nlb:fit-name-to-lines($authors[1], 3, $line-length)"/>
            </xsl:when>
            <xsl:when test="count($authors) = 2">
                <xsl:variable name="author-1-1" select="nlb:fit-name-to-lines($authors[1], 1, $line-length)" as="xs:string*"/>
                <xsl:variable name="author-1-2" select="nlb:fit-name-to-lines($authors[1], 2, $line-length)" as="xs:string*"/>
                <xsl:variable name="author-2-1" select="nlb:fit-name-to-lines($authors[2], 1, $line-length)" as="xs:string*"/>
                <xsl:variable name="author-2-2" select="nlb:fit-name-to-lines($authors[2], 2, $line-length)" as="xs:string*"/>
                
                <xsl:variable name="authors-1-2" select="($author-1-1[position() gt 1], $author-2-2[position() gt 1])" as="xs:string*"/>
                <xsl:variable name="authors-2-1" select="($author-1-2[position() gt 1], $author-2-1[position() gt 1])" as="xs:string*"/>
                
                <xsl:variable name="authors-1-2-fits" select="$author-1-1[1] = 'true' and $author-2-2[1] = 'true'" as="xs:boolean"/>
                <xsl:variable name="authors-2-1-fits" select="$author-1-2[1] = 'true' and $author-2-1[1] = 'true'" as="xs:boolean"/>
                
                <xsl:choose>
                    <xsl:when test="$authors-1-2-fits">
                        <!-- first author on 1 line, second author on 2 lines -->
                        <xsl:sequence select="('true', $authors-1-2)"/>
                    </xsl:when>
                    <xsl:when test="$authors-2-1-fits">
                        <!-- first author on 2 lines, second author on 1 line -->
                        <xsl:sequence select="('true', $authors-2-1)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- can't make 2 authors fit on 3 lines; use only first author -->
                        <xsl:sequence select="('false', $author-1-2[position() gt 1], $last-line-if-cropped)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="count($authors) gt 2">
                <xsl:variable name="author-1" select="nlb:fit-name-to-lines($authors[1], 1, $line-length)" as="xs:string*"/>
                <xsl:variable name="author-2" select="nlb:fit-name-to-lines($authors[2], 1, $line-length)" as="xs:string*"/>
                <xsl:sequence select="'false'"/>
                <xsl:choose>
                    <xsl:when test="$author-1[1] = 'true' and $author-2[1] = 'true'">
                        <!-- 2 authors fit on 2 lines -->
                        <xsl:sequence select="($author-1[2], $author-2[2])"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- can't make 2 authors fit on 2 lines; use only first author -->
                        <xsl:sequence select="nlb:fit-name-to-lines($authors[1], 2, $line-length)[position() gt 1]"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:sequence select="$last-line-if-cropped"/>
            </xsl:when>
        </xsl:choose>
    </xsl:function>
    
    
</xsl:stylesheet>