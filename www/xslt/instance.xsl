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

  <xsl:template match="kinetic">
    <html>
    <head>
        <link rel="stylesheet" href="/css/rest.css"/>
        <title><xsl:value-of select="instance/@key" /></title>
    </head>
    <body>
      <div class="listing"> 
        <table>
          <tr>
            <th class="header" colspan="2"><xsl:value-of select="instance/@key" /></th>
          </tr>
          <xsl:for-each select="instance">
            <xsl:apply-templates select="attr" />
          </xsl:for-each>
        </table>
      </div>
    </body>
    </html>
  </xsl:template>
  
  <!--                                 -->
  <!-- display an individual attribute -->
  <!--                                 -->
  
  <xsl:template match="attr">
    <tr class="row_{position() mod 2}">
      <td>
        <xsl:value-of select="@name"/>
      </td>
      <td>
        <xsl:apply-templates/>
      </td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
