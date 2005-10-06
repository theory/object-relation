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
        <div id="sidebar">
          <ul>
            <xsl:for-each select="kinetic:resource">
              <xsl:apply-templates select="." />
            </xsl:for-each>
          </ul>
        </div>
      </body>
    </html>
  </xsl:template>
  
  <!--                                                  -->
  <!-- Find all resources and create hyperlinks for 'em -->
  <!--                                                  -->
  
  <xsl:template match="kinetic:resource">
    <li><a href="{@xlink:href}"><xsl:value-of select="@id" /></a></li>
  </xsl:template>

</xsl:stylesheet>