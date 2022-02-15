<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:output method="xhtml" indent="no" include-content-type="no" exclude-result-prefixes="#all"/>

    <xsl:param name="modified" as="xs:string?"/>

    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <!-- insert copyright and usage information right after the titlepage -->
    <xsl:template match="body">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:call-template name="create-copyright-page"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="create-copyright-page">
        <xsl:variable name="language" select="(/*/@xml:lang/string(.), /*/@lang/string(.), /*/head/meta[@name='dc:language']/@content/string(.), lang(/*))[1]" as="xs:string"/>
        <xsl:variable name="year" select="format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]')"/>
        <xsl:variable name="depth" select="max(//*[matches(local-name(),'^h\d$')]/xs:integer(replace(local-name(),'^h','')))"/>
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        <xsl:if test="not(upper-case($library) = ('NLB','STATPED','KABB'))">
            <xsl:message select="concat('Ukjent bibliotek i schema:library (`*850$a`): ', ($library,'(mangler)')[1])"/>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="upper-case($library) = 'NLB'">
              <xsl:choose>
                  <xsl:when test="$language = ('en', 'eng')">
                      <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                          <h1 id="copyright-headline-{generate-id()}">The Audiobook Agreement</h1>
                          <p>
                              This edition is produced by NLB in <xsl:value-of select="$year"/> pursuant to article 55
                              of the Norwegian Copyright Act and can be reproduced for private use only.
                              This copy is not to be redistributed. All digital copies are to be destroyed or returned to the publisher
                              by the end of the borrowing period. The copy will be marked so that it will be possible to trace it
                              to the borrower if misused. Violation of these terms of agreement may lead to liability according to
                              the Copyright Act. Such actions may also result in loss of the right to borrow accessible literature.
                          </p>
                      </section>
                      <section epub:type="frontmatter copyright-page" id="bookinfo-section-{generate-id()}">
                          <h1 id="bookinfo-headline-{generate-id()}">Book information</h1>
                          <p>
                              This digital talking book is narrated by the synthetic voice William and produced as a DAISY 2.02 fulltext audio book.
                              Most DAISY reading systems make it possible to navigate by headings and page numbers. If footnotes, side bars and production notes is present in the book, it is also possible to navigate using these elements.
                              If you detect any pronunciation errors in the book, please let us know at: talesyntese@nlb.no
                          </p>
                          <figure class="image"><img alt="NLB logo" src="images/{upper-case($library)}_logo.png"/></figure>
                      </section>
                  </xsl:when>
                  <xsl:when test="$language = ('nb', 'nob', 'no')">
                    <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                        <h1 id="copyright-headline-{generate-id()}">Lydbokavtalen</h1>
                        <p>
                            Denne utgaven er produsert av NLB i <xsl:value-of select="$year"/> med hjemmel i åndsverklovens §55, og kan kun kopieres til privat bruk.
                            Eksemplaret kan ikke videredistribueres. Ved låneperiodens utløp skal alle digitale eksemplar destrueres eller returneres til produsenten. 
                            Eksemplaret er merket slik at det kan spores tilbake til deg som låntaker ved misbruk. Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til slik ulovlig kopiering, kan medføre ansvar etter åndsverkloven. 
                            Slike handlinger kan også medføre tap av retten til å låne tilrettelagte lydbøker.
                        </p>
                    </section>
                      <section epub:type="frontmatter copyright-page" id="bookinfo-section-{generate-id()}">
                        <h1 id="bookinfo-headline-{generate-id()}">Bokinformasjon</h1>
                        <p>
                            DAISY-boka er lest av den syntetiske stemmen Clara, og produsert som en DAISY 2.02 fulltekst lydbok. 
                            Nynorsk og engelsk tekst leses henholdsvis av stemmene Hulda og William.
                            Lydboka er strukturert slik at overskriftene er plassert på én til seks nivåer. 
                            Kapitteloverskriftene ligger på nivå 1, som er det høyeste nivået, mens de øvrige overskriftene er plassert på lavere nivåer. 
                            De fleste avspillingssystemer for DAISY-bøker gjør det mulig å navigere mellom overskriftene, og å gå direkte til ønsket side. 
                            Vi er glade for å få tilbakemelding på ord eller vendinger som Clara uttaler feil. Vennligst send en e post til talesyntese@nlb.no. 
                            Beskriv hvilke ord som er feiluttalt og oppgi hele setningen som inneholder ordene. På forhånd takk!
                        </p>
                        <figure class="image"><img alt="NLB logo" src="images/{upper-case($library)}_logo.png"/></figure>
                    </section>
                  </xsl:when>
                  <xsl:otherwise>
                      <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                          <h1 id="copyright-headline-{generate-id()}">Lydbokavtalen</h1>
                          <p>
                              Denne utgåva er produsert av NLB i <xsl:value-of select="$year"/> med heimel i åndsverklova § 55,
                              og kan bare kopierast til privat bruk. Eksemplaret kan ikkje distribuerast vidare. Når låneperioden er over,
                              skal alle digitale eksemplar destruerast eller returnerast til produsenten. Eksemplaret er merka slik
                              at det kan sporast tilbake til deg som lånar ved misbruk. Brot på desse avtalevilkåra kan medføre ansvar
                              etter åndsverklova. Slike handlingar kan også medføre tap av retten til å låne tilrettelagde bøker.
                          </p>
                      </section>
                      <section epub:type="frontmatter copyright-page" id="bookinfo-section-{generate-id()}">
                          <h1 id="bookinfo-headline-{generate-id()}">Bokinformasjon</h1>
                          <p>
                              DAISY-boka er lesen av den syntetiske stemma Hulda, og produsert som ei DAISY 2.02 fulltekst lydbok. 
                              Bokmål og engelsk tekst lesast av stemmene Clara og William.
                              Lydboka er strukturert slik at overskriftene er plasserte på eitt til seks nivå. 
                              Kapitteloverskriftene ligg på nivå 1, som er det høgste nivået, medan dei andre overskriftene er plasserte på lågare nivå. 
                              Dei fleste avspelingssystem for DAISY-bøker gjer det mogleg å navigera mellom overskriftene, og å gå direkte til ønskte side. 
                              Vi er glade for å få tilbakemelding på ord eller vendingar som Hulda uttaler feil. Ver vennleg og send ei e-post til talesyntese@nlb.no. 
                              Beskriv kva ord som er feiluttalt og heile setninga som inneheld orda. På førehand takk!
                          </p>
                          <figure class="image"><img alt="NLB logo" src="images/{upper-case($library)}_logo.png"/></figure>
                      </section>
                  </xsl:otherwise>
              </xsl:choose>
            </xsl:when>

            <xsl:when test="upper-case($library) = 'STATPED'">
                <section>
                    <xsl:choose>
                        <xsl:when test="$language = ('en', 'eng')">
                            <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                                <h1 id="copyright-headline-{generate-id()}">Copyright</h1>
                                <p>Information about copyright for Statped in english here.</p>
                            </section>
                            <section epub:type="frontmatter" id="bookinfo-section-{generate-id()}">
                                <h1 id="bookinfo-headline-{generate-id()}">Book information</h1>
                                <p>The book has <xsl:value-of select="if ($depth = 1) then 'one level'
                                    else concat(if ($depth = 2) then 'two'
                                    else if ($depth = 3) then 'three'
                                    else if ($depth = 4) then 'four'
                                    else if ($depth = 5) then 'five'
                                    else 'six',
                                    ' levels')"/> of headings.</p>
                                <figure class="image"><img alt="NLB logo" src="images/{upper-case($library)}_logo.png"/></figure>
                            </section>
                        </xsl:when>
                        <xsl:otherwise>
                            <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                                <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                                <p>Informasjon om opphavsrett for Statped på norsk her.</p>
                            </section>
                        </xsl:otherwise>
                    </xsl:choose>
                </section>
            </xsl:when>

            <xsl:when test="upper-case($library) = 'KABB'">
                <!-- Ingenting her enda -->
            </xsl:when>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
