import _ from 'underscore';

export const notes = state => state.notes;
export const targetNoteHash = state => state.targetNoteHash;

export const getNotesData = state => state.notesData;
export const getNotesDataByProp = state => prop => state.notesData[prop];

export const getIssueData = state => state.issueData;
export const getIssueDataByProp = state => prop => state.issueData[prop];

export const getUserData = state => state.userData || {};
export const getUserDataByProp = state => prop => state.userData && state.userData[prop];

export const notesById = state => state.notes.reduce((acc, note) => {
  note.notes.every(n => Object.assign(acc, { [n.id]: n }));
  return acc;
}, {});

const reverseNotes = array => array.slice(0).reverse();
const isLastNote = (note, state) => !note.system &&
  state.userData !== undefined && note.author &&
  note.author.id === state.userData.id;

export const getCurrentUserLastNote = state => _.flatten(
    reverseNotes(state.notes)
    .map(note => reverseNotes(note.notes)),
  ).find(el => isLastNote(el, state));

export const getDiscussionLastNote = state => discussion => reverseNotes(discussion.notes)
  .find(el => isLastNote(el, state));
