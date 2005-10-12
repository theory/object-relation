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
        <xsl:if test="kinetic:class_key">
        <script language="JavaScript1.2" type="text/javascript" src="/js/Kinetic/Search.js"/>
        </xsl:if>
      </head>
      <body>
        <xsl:if test="kinetic:class_key">
          <xsl:attribute name="onload">document.search_form.search.focus()</xsl:attribute>
        </xsl:if>
        
        <!--                         -->
        <!-- Build the resource list -->
        <!--                         -->

        <div id="sidebar">
          <ul>
            <xsl:for-each select=".">
              <xsl:apply-templates select="kinetic:resource" />
            </xsl:for-each>
          </ul>
        </div>

        <!--                        -->
        <!-- build the search form  -->
        <!-- if there's a class key -->
        <!--                        -->

        <xsl:if test="kinetic:class_key">
        <div class="search">
          <form action="/{kinetic:path}" method="get" name="search_form" onsubmit="doSearch(this); return false">
            <input type="hidden" name="_class_key" value="{kinetic:class_key}"/>
            <input type="hidden" name="_domain"    value="{kinetic:domain}"/>
            <input type="hidden" name="_path"      value="{kinetic:path}"/>
            <input type="hidden" name="_type"      value="{kinetic:type}"/>
            <table>
              <xsl:for-each select="kinetic:search_parameters">
                <xsl:apply-templates select="kinetic:parameter" />
              </xsl:for-each>
              <tr>
                <td colspan="2"><input type="submit" value="Search"/></td>
              </tr>
            </table>
          </form>
        </div>
        </xsl:if>
        
        <div class="listing">
          <table>

            <xsl:choose>

              <!-- the search has results -->

              <xsl:when test="kinetic:instance/kinetic:attribute">
              
                <!-- Build table headers -->

                <tr>
                  <xsl:for-each select="kinetic:instance[1]/kinetic:attribute">
                  <th class="header">
                    <a>
                      <xsl:attribute name="href">
                        <xsl:variable name="attr" select="@name"/>
                        <xsl:value-of select="/kinetic:resources/kinetic:sort[@name=$attr]"/>
                      </xsl:attribute>
                      <xsl:value-of select="@name"/>
                    </a>
                  </th>
                  </xsl:for-each>
                </tr>

                <!-- Build table rows -->

                <xsl:for-each select=".">
                  <xsl:apply-templates select="kinetic:instance" />
                </xsl:for-each>
              </xsl:when>
              
              <!-- the search has no results -->
              
              <xsl:otherwise>
                <tr><td><xsl:value-of select="kinetic:instance/@id"/></td></tr>
              </xsl:otherwise>
            </xsl:choose>

          </table>
        </div>

        <!--                                        -->
        <!-- Only build page links if we have pages -->
        <!--                                        -->

        <xsl:if test="kinetic:pages">
        <div class="pages">
          <p>
            <xsl:for-each select="kinetic:pages">
              <xsl:apply-templates select="kinetic:page" />
            </xsl:for-each>
          </p>
        </div>
        </xsl:if>
      </body>
    </html>
  </xsl:template>
  
<xsl:template name="get-sort-href">
  <xsl:param name="attr"/>
  <!--xsl:value-of select="kinetic:sort[ @name = $attr ]"/-->
  <xsl:value-of select="/kinetic:resources/kinetic:sort[1]"/>
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
        <xsl:choose>
        
          <!--                         -->
          <!-- build <select/> widgets -->
          <!--                         -->

          <xsl:when test="@widget = 'select'">
          <select name="{@type}">
            <xsl:for-each select="kinetic:option">
              <option value="{@name}">
                <xsl:if test="@selected = 'selected'">
                  <xsl:attribute name="selected">selected</xsl:attribute>
                </xsl:if>
                <xsl:apply-templates/>
              </option>
            </xsl:for-each>
          </select>
          </xsl:when>
          
          <!--                        -->
          <!-- build <input/> widgets -->
          <!--                        -->
          
          <xsl:otherwise>
          <input type="text" name="{@type}" value="{.}"/>
          </xsl:otherwise>

        </xsl:choose>
      </td>
    </tr>
  </xsl:template>

  <!--                                                  -->
  <!-- Find all resources and create hyperlinks for 'em -->
  <!--                                                  -->
  
  <xsl:template match="kinetic:resource">
    <li>
      <a href="{@xlink:href}"><xsl:value-of select="@id" /></a>
    </li>
  </xsl:template>

  <!--                                                  -->
  <!-- Find all instances and create hyperlinks for 'em -->
  <!--                                                  -->
  
  <xsl:template match="kinetic:instance">
    <tr class="row_{position() mod 2}">
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
