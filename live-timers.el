;;; live-timers.el --- Autorefresh for timer-list-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Karim Aziiev <karim.aziiev@gmail.com>

;; Author: Karim Aziiev <karim.aziiev@gmail.com>
;; URL: https://github.com/KarimAziev/live-timers
;; Version: 0.1.0
;; Keywords: maint
;; Package-Requires: ((emacs "26.1"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Autorefresh for timer-list-mode

;;; Code:


(require 'cl-print)

(defcustom live-timers-refresh-delay 0.5
  "How many seconds to wait before refreshing entries in `timer-list-mode'."
  :type 'integer
  :group 'live-timers)

(defun live-timers--debounce (timer-sym delay fn &rest args)
  "Debounce execution FN with ARGS for DELAY.
TIMER-SYM is a symbol to use as a timer."
  (when-let ((timer-value (symbol-value timer-sym)))
    (when (timerp timer-value)
      (cancel-timer timer-value))
    (set timer-sym nil))
  (set timer-sym (apply #'run-with-timer delay
                        nil
                        #'live-timers--run-in-buffer
                        (current-buffer)
                        fn
                        args)))


(defun live-timers--run-in-buffer (buffer fn &rest args)
  "Apply FN with ARGS in BUFFER if it is live."
  (when (and buffer (buffer-live-p buffer))
    (with-current-buffer buffer
      (apply fn args))))

(defvar-local live-timers--refresh-timer nil)

(defun live-timers-list-timers--revert ()
  "Update tabulated entries in the current buffer."
  (when (get-buffer-window (current-buffer))
    (setq tabulated-list-entries (seq-map-indexed
                                  (lambda (timer i)
                                    (list
                                     i
                                     `[ ;; Idle.
                                       ,(propertize
                                         (if (aref timer 7) "   *" " ")
                                         'help-echo "* marks idle timers"
                                         'timer timer)
                                         ;; Next time.
                                       ,(propertize
                                         (let ((time (list (aref timer 1)
                                                           (aref timer 2)
                                                           (aref timer 3))))
                                           (format "%12s"
                                                   (format-seconds
                                                    "%dd %hh %mm %z%,1ss"
                                                    (float-time
                                                     (if (aref
                                                          timer 7)
                                                         time
                                                       (time-subtract
                                                        time nil))))))
                                         'help-echo "Time until next invocation")
                                         ;; Repeat.
                                       ,(let ((repeat (aref timer 4)))
                                          (cond ((numberp repeat)
                                                 (propertize
                                                  (format "%12s" (format-seconds
                                                                  "%x%dd %hh %mm %z%,1ss"
                                                                  repeat))
                                                  'help-echo "Repeat interval"))
                                                ((null repeat)
                                                 (propertize "           -"
                                                             'help-echo
                                                             "Runs once"))
                                                (t
                                                 (format "%12s" repeat))))
                                                 ;; Function.
                                       ,(propertize
                                         (let ((cl-print-compiled 'static)
                                               (cl-print-compiled-button nil)
                                               (print-escape-newlines t))
                                           (cl-prin1-to-string (aref timer 5)))
                                         'help-echo "Function called by timer")]))
                                  (append timer-list timer-idle-list)))
    (tabulated-list-print t t)))

(defun live-timers-list-timers-revert ()
  "Update tabulated entries in the current buffer and reschedule update timer."
  (live-timers-list-timers--revert)
  (live-timers-schedule-revert))

(defun live-timers-schedule-revert ()
  "Schedule updating tabulated entries in the current buffer."
  (live-timers--debounce 'live-timers--refresh-timer live-timers-refresh-delay
                         'live-timers-list-timers-revert))

;;;###autoload
(define-minor-mode live-timers-live-mode
  "Toggle autorefresh in `timer-list-mode' when this mode on."
  :group 'live-timers
  :global nil
  (when (timerp live-timers--refresh-timer)
    (cancel-timer live-timers--refresh-timer))
  (setq live-timers--refresh-timer nil)
  (when (and (derived-mode-p 'timer-list-mode)
             live-timers-live-mode)
    (live-timers-schedule-revert)))

(provide 'live-timers)
;;; live-timers.el ends here