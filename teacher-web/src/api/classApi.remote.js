import request from './request'

export const getDashboard = () => request.get('/teacher/dashboard')

export const getClasses = () => request.get('/classes')

export const createClass = (form) => request.post('/classes', form)

export const getClassDetail = (id) => request.get(`/classes/${id}`)

export const getClassReport = (id) => request.get(`/classes/${id}/report`)

