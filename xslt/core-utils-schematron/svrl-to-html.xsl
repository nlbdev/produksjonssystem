<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:j4r="http://jats4r.org/ns"
                exclude-result-prefixes="svrl"
                version="2.0">
    
  <!-- Based on https://github.com/JATS4R/validator -->

  <xsl:output method="html" omit-xml-declaration="yes" include-content-type="no" standalone="no" indent="yes"/>

  <xsl:template match="svrl:schematron-output">
    <html>
      <head>
        <meta charset="utf-8"/>
        <title>Rapport</title>
        <style>
          html{font-family:Arial, Helvetica, sans-serif; overflow-y:scroll; min-width:1000px;}
          table{text-align:left;min-width:50%;}
        </style>
      </head>
      <body>
        <h1>Valideringsrapport</h1>
        <div>
          <h2>Tester utført:</h2>
          <ul>
            <xsl:apply-templates select="svrl:active-pattern"/>
          </ul>
          
          <h2>Problemer:</h2>
          <xsl:variable name='problems' select='svrl:failed-assert|svrl:successful-report'/>
          <xsl:choose>
            <xsl:when test="$problems">
              <table class="results">
                <thead>
                  <tr>
                    <th>Sted</th>
                    <th>Melding</th>
                  </tr>
                </thead>
                <tbody>
                  <xsl:for-each select="$problems">
                    <xsl:call-template name='problem-report'/>
                  </xsl:for-each>
                </tbody>
              </table>
            </xsl:when>
            <xsl:otherwise>
              <p>Ingen problemer funnet.</p>
            </xsl:otherwise>
          </xsl:choose>
        </div>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="svrl:active-pattern">
    <li>
      <xsl:value-of select="@name"/>
    </li>
  </xsl:template>

  <xsl:template name='problem-report'>
    <xsl:variable name='active-pattern' select='preceding-sibling::svrl:active-pattern[1]/@name'/>
    <xsl:variable name='topic' select='replace($active-pattern, "(.*)-.*", "$1")'/>
    <xsl:variable name='level'>
      <xsl:choose>
        <xsl:when test="contains($active-pattern, 'errors')">
          <xsl:value-of select="'error'"/>
        </xsl:when>
        <xsl:when test="contains($active-pattern, 'warnings')">
          <xsl:value-of select="'warn'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'info'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td class='{$level}'>
        <!-- Insert zero-width spaces to allow the browser to wrap the location cell -->
        <span class='xpath-display'>
          <xsl:value-of select="replace(@location, '/', '&#x200B;/&#x200B;')"/>
        </span>
        <span class='xpath-location'>
          <xsl:value-of select='@location'/>
        </span>
      </td>
      <td class='{$level}'>
        <xsl:apply-templates select="svrl:text"/>
      </td>
    </tr>
  </xsl:template>
</xsl:stylesheet>
