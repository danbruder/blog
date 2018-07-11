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
    'gatsby-plugin-react-helmet',
  ],
}
