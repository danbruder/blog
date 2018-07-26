var path = require('path')
var _ = require('lodash')

var config = require('./src/config')
const PAGE_SIZE = 10

exports.createPages = ({ graphql, actions }) => {
  const { createPage } = actions
  const blogTemplate = path.resolve(`src/templates/blog.js`)
  const blogListTemplate = path.resolve(`src/templates/blogList.js`)

  return new Promise((resolve, reject) => {
    resolve(
      graphql(
        `
          query {
            posts: allContentfulPost(sort: { order: DESC, fields: [date] }) {
              edges {
                node {
                  slug
                }
              }
            }
          }
        `
      ).then(result => {
        if (result.errors) {
          reject(result.errors)
        }

        // Break the entries into chunks according to
        let chunks = _.chunk(result.data.posts.edges, PAGE_SIZE)

        chunks.forEach((chunk, index) => {
          if (index == 0) {
            createPage({
              path: `blog`,
              component: blogListTemplate,
              context: {
                skip: PAGE_SIZE * index,
                limit: PAGE_SIZE,
                pageNumber: index + 1,
                hasNextPage: index != chunks.length - 1,
                nextPageLink: `/blog/page/${index + 2}`,
              },
            })
          }
          createPage({
            path: `blog/page/${index + 1}`,
            component: blogListTemplate,
            context: {
              skip: PAGE_SIZE * index,
              limit: PAGE_SIZE,
              pageNumber: index + 1,
              hasNextPage: index != chunks.length - 1,
              nextPageLink: `/blog/page/${index + 2}`,
            },
          })
        })

        // Create a blog page
        result.data.posts.edges.forEach(({ node }) => {
          // loop over split pages
          createPage({
            path: `${config.blogRootPath}/${node.slug}`,
            component: blogTemplate,
            context: {
              slug: node.slug,
            },
          })
        })
      })
    )
  })
}
