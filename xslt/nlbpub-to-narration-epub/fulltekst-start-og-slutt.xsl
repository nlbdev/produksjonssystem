<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 14.02.2018
    -->
    
    <xsl:template name="generer-startinformasjon">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <xsl:call-template name="generer-tittel"/>
        <!-- PSPS: Alltid før cover,sier Roald -->
        <xsl:call-template name="copyright-page"/>
        <xsl:call-template name="info-om-boka"/>
    </xsl:template>

    <xsl:template name="generer-tittel">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <section epub:type="frontmatter titlepage" id="nlb-level1-tittel">
            <h1 epub:type="fulltitle" class="title">
                <xsl:apply-templates select="//title/child::node()"/>
            </h1>
            <p>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>by </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>av </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                <xsl:text>.</xsl:text>
            </p>
            <p>
                <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>Read by </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text>.</xsl:text>
                    </xsl:when>
                    <xsl:when test="$SPRÅK.nn">
                        <xsl:text>Det er </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text> som les.</xsl:text>
                    </xsl:when>
                    <xsl:when test="$SPRÅK.se">
                        <xsl:text>Lea </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text> guhte lohká.</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Det er </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text> som leser.</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </p>
            
            <xsl:if test="upper-case($library) = 'STATPED'">
                <figure class="image"><img alt="{$library} logo" src="{upper-case($library)}_logo.png"/></figure>
            </xsl:if>
        </section>
    </xsl:template>

    <xsl:template name="generer-sluttinformasjon">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <hr class="separator"/>
        <xsl:choose>
            
            <xsl:when test="upper-case($library) = 'STATPED'">
                <h1>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:text>Informasjon om originalbok og lydbok</xsl:text>
                </h1>
                <dl>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:variable name="title" select="ancestor::html/head/title/text()" as="xs:string?"/>
                    <xsl:variable name="authors" select="ancestor::html/head/meta[@name='dc:creator']/string(@content)" as="xs:string*"/>
                    <xsl:variable name="language" select="(ancestor-or-self::*/(@xml:lang/string(.), @lang/string(.)), /*/head/meta[@name='dc:language']/@content/string(.))[1]" as="xs:string"/>
                    <xsl:variable name="language" select="if (count($language)) then tokenize($language, '-')[1] else $language" as="xs:string?"/>
                    <xsl:variable name="originalPublisher" select="ancestor::html/head/meta[@name='dc:publisher.original']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="originalYear" select="ancestor::html/head/meta[@name='dc:date.issued.original']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="originalEdition" select="ancestor::html/head/meta[@name='schema:bookEdition.original']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="originalIsbn" select="ancestor::html/head/meta[@name='schema:isbn']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="productionYear" select="format-date(current-date(), '[Y]')" as="xs:string"/>
                    
                    <dt>Boktittel:</dt>
                    <dd><xsl:value-of select="$title"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Forfattarar:' else 'Forfattere:'"/></dt>
                    <xsl:for-each select="$authors">
                        <dd><xsl:value-of select="."/></dd>
                    </xsl:for-each>
                    
                    <xsl:choose>
                        <xsl:when test="$language = ('nb', 'nn')">
                            <dt>Målform:</dt>
                        </xsl:when>
                        <xsl:otherwise>
                            <dt>Språk:</dt>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="$language = 'no'">
                            <dd>Norsk</dd>
                        </xsl:when>
                        <xsl:when test="$language = 'nb'">
                            <dd>Bokmål</dd>
                        </xsl:when>
                        <xsl:when test="$language = 'nn'">
                            <dd>Nynorsk</dd>
                        </xsl:when>
                        <xsl:when test="$language = 'en'">
                            <dd>Engelsk</dd>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- TODO: koble flere språkkoder til språknavn -->
                            <dd><xsl:value-of select="$language"/></dd>
                        </xsl:otherwise>
                    </xsl:choose>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Utgjevar av originalboka:' else 'Utgiver av originalboka:'"/></dt>
                    <dd><xsl:value-of select="if ($originalPublisher) then $originalPublisher else 'Ukjent'"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Utgjevingsår:' else 'Utgivelsesår:'"/></dt>
                    <dd><xsl:value-of select="if ($originalYear) then $originalYear else 'Ukjent'"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Utgåve og opplag:' else 'Utgave og opplag:'"/></dt>
                    <dd><xsl:value-of select="if ($originalEdition) then $originalEdition else 'Ukjent'"/></dd>
                    
                    <dt>ISBN originalbok:</dt>
                    <dd><xsl:value-of select="if ($originalIsbn) then $originalIsbn else 'Ukjent'"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Ansvarleg utgjevar av lydboka:' else 'Ansvarlig utgiver av lydboka:'"/></dt>
                    <dd>Statped</dd>
                    
                    <dt>Produksjonsår:</dt>
                    <dd><xsl:value-of select="$productionYear"/></dd>
                </dl>
            </xsl:when>
            
            <xsl:otherwise>
                <p>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>You've been listening to </xsl:text>
                            <em>
                                <xsl:apply-templates select="//title/child::node()"/>
                            </em>
                            <xsl:text>, by </xsl:text>
                            <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                            <xsl:text>.</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.nn">
                            <xsl:text>Du høyrde </xsl:text>
                            <em>
                                <xsl:apply-templates select="//title/child::node()"/>
                            </em>
                            <xsl:text>, av </xsl:text>
                            <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                            <xsl:text>.</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.se">
                            <xsl:text>Don logai </xsl:text>
                            <em>
                                <xsl:apply-templates select="//title/child::node()"/>
                            </em>
                            <xsl:text>, lea </xsl:text>
                            <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                            <xsl:text>.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Du hørte </xsl:text>
                            <em>
                                <xsl:apply-templates select="//title/child::node()"/>
                            </em>
                            <xsl:text>, av </xsl:text>
                            <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                            <xsl:text>.</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </p>
                <p>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>Read by </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text>.</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.nn">
                            <xsl:text>Det var </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text> som las.</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.se">
                            <xsl:text>Lei </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text> guhte logai.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Det var </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text> som leste.</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </p>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="lydbokavtalen">
        <xsl:message select="'WARNING: the template ''lydbokavtalen'' is deprecated. Please use the template ''copyright-page'' instead.'"/>
        <xsl:call-template name="copyright-page"/>
    </xsl:template>

</xsl:stylesheet>
