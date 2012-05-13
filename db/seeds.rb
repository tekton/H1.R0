# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
Image.delete_all
Image.create(id: 1, name: "Three Boys", location: "test/agee-467.jpg")
Image.create(id: 2, name: "The Leg", location: "test/agee-482.jpg")
Image.create(id: 3, name: "Kaitlin", location: "test/IMG_5421.jpg")
Image.create(id: 4, name: "Tyler", location: "test/IMG_5349.jpg")
