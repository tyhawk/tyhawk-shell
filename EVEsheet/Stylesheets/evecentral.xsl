<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:csv="csv:csv">
<xsl:output method="text"/>
<xsl:variable name="delimiter" select="';'"/>
<xsl:variable name="fieldNames" select="'yes'"/>

<csv:columns>
	<column>Type ID</column>
	<column>Buy avg</column>
	<column>Buy min</column>
	<column>Buy max</column>
	<column>Buy volume</column>
	<column>Sell avg</column>
	<column>Sell min</column>
	<column>Sell max</column>
	<column>Sell volume</column>
	<column>All avg</column>
	<column>All volume</column>
	<column>All median</column>
</csv:columns>

<xsl:template match="/">
	<!-- Output the CSV header -->
	<xsl:for-each select="document('')/*/csv:columns/*">
		<xsl:value-of select="."/>
		<xsl:if test="position() != last()">
			<xsl:value-of select="$delimiter"/>
		</xsl:if>
	</xsl:for-each>
	<xsl:text>&#xA;</xsl:text>
	<xsl:apply-templates select="evec_api/marketstat"/>
</xsl:template>

<xsl:template match="*">
	<xsl:for-each select="type">
		<xsl:value-of select="@id"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="buy/avg"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="buy/min"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="buy/max"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="buy/volume"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="sell/avg"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="sell/min"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="sell/max"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="sell/volume"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="all/avg"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="all/volume"/>
		<xsl:value-of select="$delimiter"/>
		<xsl:value-of select="all/median"/>
		<xsl:text>&#xA;</xsl:text>
	</xsl:for-each>
</xsl:template>
</xsl:stylesheet>


<!--
		
		<xsl:if test="position() != last()">
			<xsl:value-of select="$delimiter"/>
		</xsl:if>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:csv="csv:csv">
	<xsl:output method="text" encoding="utf-8"/>
	<xsl:variable name="delimiter" select="';'"/>
	<xsl:template match="evec_api/marketstat">
		<xsl:for-each select="evec_api/marketstat/type">
			<xsl:text><xsl:value-of select="@id"/>
			<xsl:value-of select="all/volume"/>
			<xsl:value-of select="buy/avg"/>
			<xsl:value-of select="sell/avg"/>
			<xsl:value-of select="all/median"/>
			<xsl:value-of select="all/avg"/>
			<xsl:value-of select="$delimiter"/>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet> -->