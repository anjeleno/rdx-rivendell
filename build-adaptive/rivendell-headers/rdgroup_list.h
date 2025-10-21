// rdgroup_list.h
//
// A list container for Rivendell Groups
//
//   (C) Copyright 2002-2020 Fred Gleason <fredg@paravelsystems.com>
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.
//
//   You should have received a copy of the GNU General Public
//   License along with this program; if not, write to the Free Software
//   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
//

#ifndef RDGROUP_LIST_H
#define RDGROUP_LIST_H

#include <QStringList>

class RDGroupList
{
 public:
  RDGroupList();
  QString serviceName() const;
  void setServiceName(const QString &str);
  void clear();
  int size() const;
  QString group(int n) const;
  bool groupIsValid(QString group);

 private:
  QString d_service_name;
  QStringList d_groups;
};


#endif  // RDGROUP_LIST_H
