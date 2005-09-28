<xsl:stylesheet version="1.0"
      xmlns:kinetic="http://www.kineticode.com/rest"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      xmlns:fo="http://www.w3.org/1999/XSL/Format"
      xmlns="http://www.w3.org/1999/xhtml">
  <xsl:output method="xml"
    doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"  
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
    indent="yes"/>

  <xsl:template match="kinetic:resources">
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <link rel="stylesheet" href="/css/rest.css"/>
        <title><xsl:value-of select="kinetic:description" /></title>
      </head>
      <body>
        <div class="listing">
          <table>
            <tr>
              <th class="header"><xsl:value-of select="kinetic:description" /></th>
            </tr>
            <xsl:for-each select=".">
              <xsl:apply-templates select="kinetic:resource" />
            </xsl:for-each>
          </table>
        </div>

        <!--                                        -->
        <!-- Only build page links if we have pages -->
        <!--                                        -->

        <xsl:if test="kinetic:pages">
          <p>
            <xsl:for-each select="kinetic:pages">
              <xsl:apply-templates select="kinetic:page" />
            </xsl:for-each>
          </p>
        </xsl:if>
      </body>
    </html>
  </xsl:template>
  

  <!--                                                  -->
  <!-- Find all instances and create hyperlinks for 'em -->
  <!--                                                  -->
  
  <xsl:template match="kinetic:resource">
    <tr class="row_{position() mod 2}">
      <td>
        <a href="{@xlink:href}"><xsl:value-of select="@id" /></a>
      </td>
    </tr>
  </xsl:template>

  <!--                                              -->
  <!-- Find all pages and create hyperlinks for 'em -->
  <!-- ... but don't create a link to current page  -->
  <!--                                              -->

  <xsl:template match="kinetic:page">
    <xsl:choose>
      <xsl:when test="@xlink:href = '#'">
        <xsl:value-of select="@id" />
      </xsl:when>
      <xsl:otherwise>
        <a href="{@xlink:href}"><xsl:value-of select="@id" /></a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
