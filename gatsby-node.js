var config = require('./src/config')
var _ = require('lodash')

var path = require('path')
const PAGE_LIMIT = 5

exports.createPages = ({ graphql, actions }) => {
  const { createPage } = actions
  //const projectTemplate = path.resolve(`src/templates/project.js`)
  //const serviceTemplate = path.resolve(`src/templates/service.js`)
  const blogTemplate = path.resolve(`src/templates/blog.js`)
  const blogListTemplate = path.resolve(`src/templates/blogList.js`)

  return new Promise((resolve, reject) => {
    // Query for markdown nodes to use in creating pages.
    resolve(
      graphql(
        `
          query {
            categories: allContentfulCategory {
              edges {
                node {
                  title
                }
              }
            }
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

        let chunks = _.chunk(result.data.posts.edges, PAGE_LIMIT)

        chunks.forEach((chunk, index) => {
          createPage({
            path: `blog/page/${index + 1}`,
            component: blogListTemplate,
            context: {
              skip: PAGE_LIMIT * index,
              limit: PAGE_LIMIT,
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

        // Categories
        //result.data.categories.edges.forEach(({ node }) => {
        //// loop over split pages
        //createPage({
        //path: `${config.categoryRootPath}/${node.slug}`,
        //component: blogTemplate,
        //context: {
        //slug: node.slug,
        //},
        //})
        //})
      })
    )
  })
}
