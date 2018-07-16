import React from 'react'
import MetaTags from 'react-meta-tags'

export default props => {
  const defaultTitle = `DEB Associates`
  const secondaryTitle = `West Michigan Custom Electronics Design and Development`

  const fullTitle = props.title
    ? `${props.title} | ${defaultTitle} | ${secondaryTitle}`
    : `${defaultTitle} | ${secondaryTitle}`
  const socialTitle = props.title ? props.title : defaultTitle

  const defaultDescription = `West Michigan Custom Electronics Design and Development`
  const description = props.description ? props.description : defaultDescription

  const type = props.type ? props.type : 'website'
  const url = props.url
    ? `https://debassociates.com/${props.url}`
    : `https://debassociates.com/`

  return (
    <MetaTags>
      <title>{fullTitle}</title>
      <meta name="description" content={description} />
      <meta name="twitter:card" content="summary" />
      <meta name="twitter:site" content="@debassociates" />
      <meta name="twitter:title" content={socialTitle} />
      <meta name="twitter:description" content={description} />
      <meta name="twitter:creator" content="@debassociates" />
      {props.imageUrl && <meta name="twitter:image" content={props.imageUrl} />}

      <meta property="og:title" content={socialTitle} />
      <meta property="og:type" content={type} />
      <meta property="og:url" content={url} />
      {props.imageUrl && <meta property="og:image" content={props.imageUrl} />}
      <meta property="og:description" content={description} />
      <meta property="og:site_name" content="DEB Associates" />
    </MetaTags>
  )
}
