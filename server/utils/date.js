const SHANGHAI_TIME_ZONE = 'Asia/Shanghai';

function getDatePart(parts, type) {
  const part = parts.find(item => item.type === type);
  return part ? part.value : '';
}

function getShanghaiDateString(date = new Date()) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: SHANGHAI_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  const parts = formatter.formatToParts(date);
  const year = getDatePart(parts, 'year');
  const month = getDatePart(parts, 'month');
  const day = getDatePart(parts, 'day');
  return `${year}-${month}-${day}`;
}

function getCurrentYearMonth() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

module.exports = {
  getShanghaiDateString,
  getCurrentYearMonth
};
