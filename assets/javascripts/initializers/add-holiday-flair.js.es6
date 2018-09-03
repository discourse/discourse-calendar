import { withPluginApi } from 'discourse/lib/plugin-api';

function customBool(field) {
  if (field) {
    return Array.isArray(field) ?
      field.some(x => x === 't') :
      field === 't';
  }
  return false;
}

export default {
  name: 'add-holiday-flair',
  initialize() {
    withPluginApi('0.1', api => {
      const usersOnHoliday = Discourse.Site.current().users_on_holiday;

      api.addPosterIcon(cfs => {
        const onHoliday = customBool(cfs.on_holiday);
        if (!onHoliday) { return; }

        return { emoji: 'desert_island', className: 'holiday', title: 'on holiday' };
      });

      api.decorateCooked($elem => {
        const mentions = $(".mention", $elem);

        if (usersOnHoliday.length === 0 || mentions.length === 0) {
          return;
        }

        mentions.each((i, el) => {
          const username = $(el).text().replace("@", "");

          if (usersOnHoliday.includes(username)) {
            $(el).append('<i class="fa fa-calendar d-icon d-icon-calendar" title="on holiday"></i>');
          }
        });
      });
    });
  }
};
