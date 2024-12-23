console.log("Welcome to the BrightShinyRadio website!");

function playlistApiToTable() {
  fetch("https://ev0sbdo455.execute-api.us-east-1.amazonaws.com/prod")
    .then((res) => {
      if (!res.ok) {
        throw new Error
          (`HTTP error! Status: {res.status}`);
      }
      return res.json();
    })
    .then((data) => {
      data.forEach(value => {
        tr = document.getElementsByTagName('table')[0].insertRow();

        tdWhen = tr.insertCell();
        time = document.createElement('time');
        time.setAttribute('datetime', value.timeDatetime);
        tdWhen.appendChild(time);
        tdWhen.appendChild(document.createTextNode(value.when));

        tdArtist = tr.insertCell();
        tdArtist.appendChild(document.createTextNode(value.artist));

        tdTitle = tr.insertCell();
        tdTitle.appendChild(document.createTextNode(value.title));

        tdLength = tr.insertCell();
        tdLength.setAttribute("class", "duration");
        tdLength.appendChild(document.createTextNode(value.length));
      });

    })
    .catch((error) =>
      console.error("Unable to fetch data:", error));
}

// Wait for this event to fetch the playlist for the table
document.addEventListener('DOMContentLoaded', function () {
  playlistApiToTable();
}, false);
