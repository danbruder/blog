module.exports = {
  siteMetadata: {
    title: 'DEB Associates',
    siteUrl: `https://debassociates.com`,
  },
  plugins: [
    {
      resolve: `gatsby-source-contentful`,
      options: {
        spaceId: `6d2kjfv47hcs`,
        accessToken: `dd274fe947669d0fb05fa8038b81b1c2db70930a6896cb7d9553d0f1eefb91f3`,
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
        trackingId: 'UA-68629017-1',
        anonymize: false,
      },
    },
    `gatsby-plugin-sharp`,
    `gatsby-transformer-sharp`,
    {
      resolve: `gatsby-plugin-favicon`,
      options: {
        logo: './src/pages/img/logogreen.png',
        injectHTML: true,
        icons: {
          android: true,
          appleIcon: true,
          appleStartup: true,
          coast: false,
          favicons: true,
          firefox: true,
          twitter: true,
          yandex: false,
          windows: true,
        },
      },
    },
    {
      resolve: `gatsby-plugin-google-fonts`,
      options: {
        fonts: [
          `IBM Plex Sans\:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i`,
        ],
      },
    },
  ],
}
