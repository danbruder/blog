module.exports = {
  siteMetadata: {
    title: 'Dan Bruder',
    siteUrl: `https://danbruder.com`,
  },
  plugins: [
    {
      resolve: `gatsby-source-contentful`,
      options: {
        spaceId: `mkfpbp2zqk3q`,
        accessToken: `df085b3e2af8879d4f0bf71afa89fb090fbc1620389f2d612a8d98b635cdd34d`,
      },
    },
    {
      resolve: `gatsby-plugin-sitemap`,
    },
    {
      resolve: `gatsby-transformer-remark`,
      options: {
        plugins: [
          {
            resolve: `gatsby-remark-prismjs`,
            options: {
              classPrefix: 'language-',
              inlineCodeMarker: null,
            },
          },
        ],
      },
    },
    {
      resolve: `gatsby-plugin-google-analytics`,
      options: {
        trackingId: 'UA-119994892-1',
        anonymize: false,
      },
    },
    `gatsby-plugin-sharp`,
    `gatsby-transformer-sharp`,

    {
      resolve: `gatsby-plugin-google-fonts`,
      options: {
        fonts: [
          `IBM Plex Sans\:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i`,
          `IBM Plex Mono\:300,300i,400,400i,500,500i,700,700i`,
        ],
      },
    },
    `gatsby-plugin-react-helmet`,
  ],
}
