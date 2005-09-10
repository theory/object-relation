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
        <title><xsl:value-of select="kinetic:description" /></title>
        <xsl:if test="kinetic:class_key">
        <script language="JavaScript1.2" type="text/javascript" src="/js/search.js"/>
        </xsl:if>
      </head>
      <body>
        <xsl:if test="kinetic:class_key">
          <xsl:attribute name="onload">document.search_form.search.focus()</xsl:attribute>
        </xsl:if>
        
        <!--                        -->
        <!-- build the search form  -->
        <!-- if there's a class key -->
        <!--                        -->

        <xsl:if test="kinetic:class_key">
        <form method="get" name="search_form" onsubmit="javascript:do_search(this); return false">
          <input type="hidden" name="class_key" value="{kinetic:class_key}"/>
          <input type="hidden" name="domain"    value="{kinetic:domain}"/>
          <input type="hidden" name="path"      value="{kinetic:path}"/>
          <table>
            <xsl:for-each select="kinetic:search_parameters">
              <xsl:apply-templates select="kinetic:parameter" />
            </xsl:for-each>
            <tr>
              <td>Sort order:</td>
              <td>
                <select name="sort_order">
                  <option value="ASC">Ascending</option>
                  <option value="DESC">Descending</option>
                </select>
              </td>
            </tr>
            <tr>
              <td colspan="2"><input type="submit" value="Search" onclick="javascript:do_search(this)"/></td>
            </tr>
          </table>
        </form>
        </xsl:if>
        
        <table bgcolor="#eeeeee" border="1">

          <!-- Build table headers -->

          <tr>
            <xsl:for-each select="kinetic:resource[1]/kinetic:attribute">
            <th><xsl:value-of select="@name"/></th>
            </xsl:for-each>
          </tr>

          <!-- Build table rows -->

          <xsl:for-each select=".">
            <xsl:apply-templates select="kinetic:resource" />
          </xsl:for-each>
        </table>

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
  
  <!--                                                -->
  <!-- Find all parameters and create inputs for them -->
  <!--                                                -->
  
  <xsl:template match="kinetic:parameter">
    <tr>
      <td>
        <xsl:call-template name="proper-case-name">
          <xsl:with-param name="expr" select="@type"/>
        </xsl:call-template>:</td> <!-- closing td must be here due to whitespace issues -->
      <td>
        <input type="text" name="{@type}" value="{.}"/>
      </td>
    </tr>
  </xsl:template>

  <!--                                                  -->
  <!-- Find all instances and create hyperlinks for 'em -->
  <!--                                                  -->
  
  <xsl:template match="kinetic:resource">
    <tr>
      <xsl:for-each select="kinetic:attribute">
      <td><a href="{../@xlink:href}"><xsl:apply-templates/></a></td>
      </xsl:for-each>
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

  <xsl:template name="proper-case-name">
    <xsl:param name="expr"/>
    <xsl:variable name="uc" 
      select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>
    <xsl:variable name="lc" 
      select="'abcdefghijklmnopqrstuvwxyz_'"/>        
    <xsl:value-of 
      select="concat(
          translate(substring($expr,1,1),$lc,$uc), 
          translate(substring($expr, 2), '_', ' ')
      )"/>
  </xsl:template> 

</xsl:stylesheet>
