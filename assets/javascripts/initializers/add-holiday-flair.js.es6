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
    const usersOnHoliday = Discourse.Site.current().users_on_holiday;

    let classNames = [];
    usersOnHoliday.forEach(username => {
      classNames.push(`a.mention[href="/u/${username}"]:after`);
    });

    $("<style>")
      .prop("id", "users_on_holiday")
      .prop("type", "text/css")
      .html(`
      ${classNames.join(", ")} {
          content: "";
          display: inline-block;
          font: normal normal normal 14px/1 FontAwesome;
          text-rendering: auto;
          margin-left: 4px;
          -webkit-font-smoothing: antialiased;
      }`)
      .appendTo("head");

    withPluginApi('0.1', api => {
      if (!usersOnHoliday) { return; }

      api.addPosterIcon(cfs => {
        const onHoliday = customBool(cfs.on_holiday);
        if (!onHoliday) { return; }

        return { emoji: 'desert_island', className: 'holiday', title: 'on holiday' };
      });
    });
  }
};
