const DATE_SEPARATOR = `[-\/]`;
const DATE_TIME_REGEX = new RegExp(
  `[^|\\s](\\d{1,2}${DATE_SEPARATOR}\\d{1,2}${DATE_SEPARATOR}\\d{2,4}(?:\\s\\d{1,2}:\\d{2})?)$`,
  "g"
);

export default function cleanTitle(title, startsAt) {
  if (!title || !startsAt) {
    return;
  }

  const match = title.trim().match(DATE_TIME_REGEX);
  return match && match[0];
}
