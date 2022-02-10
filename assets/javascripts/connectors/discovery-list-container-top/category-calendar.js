export default {
  shouldRender(_, ctx) {
    return ctx.siteSettings.calendar_categories_outlet === ctx.name;
  },
};
